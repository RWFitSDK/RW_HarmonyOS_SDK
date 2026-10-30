import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import fs from '@ohos.file.fs';
import {
  DevicePushType,
  OpusBinConverter,
  PushData,
  RecordFileItemBean,
  RecordRealtimeDataBean,
  RecordStatusBean,
  RwBleSdk
} from 'rw_ble_sdk';

/** 录音功能页：状态/开始停止/文件列表/下载/删除/格式化，对齐 Android Demo RecordingActivity。 */
@Entry
@Component
struct RecordingPage {
  @State private status: RecordStatusBean | null = null
  @State private statusText: string = '读取录音状态中...'
  @State private files: RecordFileItemBean[] = []
  @State private filesLoading: boolean = false
  @State private transferText: string = ''
  @State private busy: boolean = false
  @State private realtimePackets: number = 0
  @State private realtimeBytes: number = 0
  @State private realtimeSequence: string = '--'
  private unsubscribePush: (() => void) | null = null
  private active: boolean = false
  private statusRequest: Promise<RecordStatusBean> | null = null
  private audioPackets: number = 0
  private audioBytes: number = 0
  private audioSequence: number = 0
  private audioFlushTimer: number = -1

  aboutToAppear(): void {
    this.active = true
    // 录音状态实时推送：录音中每隔一段时间会上报时长变化
    this.unsubscribePush = RwBleSdk.subscribePush((data: PushData) => {
      if (!this.active) return
      if (data.type === DevicePushType.RECORD_STATUS) this.applyStatus(data.value as RecordStatusBean, '(推送)')
      if (data.type === DevicePushType.RECORD_REALTIME_DATA) this.receiveRealtimeAudio(data.value as RecordRealtimeDataBean)
    })
    this.refreshStatus()
    this.refreshFiles()
  }

  aboutToDisappear(): void {
    this.active = false
    this.clearAudioFlushTimer()
    this.unsubscribePush?.()
    this.unsubscribePush = null
  }

  private showToast(message: string): void {
    promptAction.showToast({ message: message, duration: 2500 })
  }

  private applyStatus(status: RecordStatusBean, suffix: string = ''): void {
    this.status = status
    this.statusText = status.recording
      ? `${status.realtime ? '实时录音中' : '录音中'} · 已录 ${status.duration} 秒${suffix}`
      : `未在录音${suffix}`
  }

  private async refreshStatus(): Promise<boolean> {
    const request = this.statusRequest ?? RwBleSdk.getRecordStatus()
    this.statusRequest = request
    try {
      const status = await request
      if (!this.active) return false
      this.applyStatus(status)
      return true
    } catch (e) {
      if (this.active) this.statusText = `状态读取失败: ${e instanceof Error ? e.message : String(e)}`
      return false
    } finally {
      if (this.statusRequest === request) this.statusRequest = null
    }
  }

  private async toggleRecording(): Promise<void> {
    await this.controlRecording(false)
  }

  private async toggleRealtimeRecording(): Promise<void> {
    await this.controlRecording(true)
  }

  private async controlRecording(realtime: boolean): Promise<void> {
    if (this.busy) return
    if (!RwBleSdk.isBleConnected() || this.status === null) {
      this.showToast('请先连接并获取录音状态')
      return
    }
    if (realtime && this.status.recording && !this.status.realtime) {
      this.showToast('请先停止普通录音')
      return
    }
    const start = this.status?.recording !== true
    this.busy = true
    try {
      if (realtime) {
        if (start) this.resetRealtimeStats()
        await RwBleSdk.recordRealtimeControl(start)
      } else {
        await RwBleSdk.recordControl(start)
      }
      if (!(await this.refreshStatus()) || !this.active) return
      const matched = start
        ? this.status?.recording === true && this.status?.realtime === realtime
        : this.status?.recording === false
      this.showToast(matched ? (start ? '录音已开始' : '录音已停止') : '设备状态未按预期改变')
      console.info(`[RWSDK Demo] recording realtime=${realtime}, start=${start}, matched=${matched}`)
    } catch (e) {
      if (this.active) this.showToast(`操作失败: ${e instanceof Error ? e.message : String(e)}`)
    } finally {
      this.busy = false
    }
  }

  /** 只接收统计，不保存实时音频；每500ms刷新，避免逐包刷新UI或打印日志。 */
  private receiveRealtimeAudio(packet: RecordRealtimeDataBean): void {
    this.audioPackets++
    this.audioBytes += packet.audioData.length
    this.audioSequence = packet.sequence
    if (this.audioFlushTimer >= 0) return
    this.audioFlushTimer = setTimeout(() => {
      this.audioFlushTimer = -1
      if (!this.active) return
      this.realtimePackets = this.audioPackets
      this.realtimeBytes = this.audioBytes
      this.realtimeSequence = `${this.audioSequence}`
    }, 500)
  }

  private clearAudioFlushTimer(): void {
    if (this.audioFlushTimer >= 0) clearTimeout(this.audioFlushTimer)
    this.audioFlushTimer = -1
  }

  private resetRealtimeStats(): void {
    this.clearAudioFlushTimer()
    this.audioPackets = 0
    this.audioBytes = 0
    this.audioSequence = 0
    this.realtimePackets = 0
    this.realtimeBytes = 0
    this.realtimeSequence = '--'
  }

  private async refreshFiles(): Promise<void> {
    if (this.filesLoading) return
    this.filesLoading = true
    try {
      this.files = await RwBleSdk.getRecordFileList()
    } catch (e) {
      this.showToast(`列表获取失败: ${e instanceof Error ? e.message : String(e)}`)
    } finally {
      this.filesLoading = false
    }
  }

  private async downloadFile(item: RecordFileItemBean): Promise<void> {
    this.transferText = `下载开始 ID=${item.fileId} (${item.fileSize} 字节)`
    try {
      const bean = await RwBleSdk.transferRecordFile(item.fileId,
        (progress): void => {
          this.transferText = `下载中 ${Math.floor(progress.progress * 100)}% (${progress.received}/${progress.fileSize})`
        })
      const saved = this.saveRecordFile(bean.fileId, bean.duration, bean.completedAt ?? 0, bean.fileData)
      this.transferText = `下载完成 ID=${bean.fileId}，已保存 ${saved}`
    } catch (e) {
      this.transferText = `下载失败: ${e instanceof Error ? e.message : String(e)}`
    }
  }

  /** 设备原始 Opus 包经 OpusBinConverter 封装为 Ogg Opus 后写入应用沙箱 filesDir(与 Android Demo 一致)。 */
  private saveRecordFile(fileId: number, duration: number, completedAt: number, data?: Uint8Array): string {
    const opus = OpusBinConverter.convert(data ?? new Uint8Array(0))
    const ctx = this.getUIContext().getHostContext() as common.UIAbilityContext
    const stamp = completedAt > 0 ? completedAt : Math.floor(Date.now() / 1000)
    const path = `${ctx.filesDir}/record_${fileId}_${duration}_${stamp}.opus`
    const file = fs.openSync(path, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY)
    fs.writeSync(file.fd, opus.buffer)
    fs.closeSync(file)
    return path
  }

  private confirmDelete(item: RecordFileItemBean): void {
    this.getUIContext().getPromptAction().showDialog({
      title: '删除录音文件',
      message: `确认删除 ID=${item.fileId} (${this.formatTime(item.timestamp)})？删除后不可恢复。`,
      buttons: [
        { text: '取消', color: '#26312C' },
        { text: '删除', color: '#D9483B' }
      ]
    }).then((result) => {
      if (result.index !== 1) return
      RwBleSdk.deleteRecordFile(item.fileId)
        .then(() => {
          this.showToast(`ID=${item.fileId} 已删除`)
          this.refreshFiles()
          this.refreshStatus()
        })
        .catch((e: Error) => this.showToast(`删除失败: ${e.message}`))
    })
  }

  private confirmFormat(): void {
    this.getUIContext().getPromptAction().showDialog({
      title: '格式化录音区',
      message: '确认删除设备上全部录音文件？该操作不可恢复。',
      buttons: [
        { text: '取消', color: '#26312C' },
        { text: '格式化', color: '#D9483B' }
      ]
    }).then((result) => {
      if (result.index !== 1) return
      RwBleSdk.formatRecordStorage()
        .then(() => {
          this.showToast('录音区已格式化')
          this.refreshFiles()
          this.refreshStatus()
        })
        .catch((e: Error) => this.showToast(`格式化失败: ${e.message}`))
    })
  }

  private formatTime(timestamp: number): string {
    if (timestamp <= 0) return '--'
    const date = new Date(timestamp * 1000)
    const p = (v: number): string => v < 10 ? `0${v}` : `${v}`
    return `${date.getFullYear()}-${p(date.getMonth() + 1)}-${p(date.getDate())} ${p(date.getHours())}:${p(date.getMinutes())}:${p(date.getSeconds())}`
  }

  private formatSize(size: number): string {
    return size >= 1024 ? `${(size / 1024).toFixed(1)} KB` : `${size} B`
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 0 }) {
          Row({ space: 10 }) {
            Text('‹').fontSize(34).fontColor('#26312C').width(38)
              .onClick(() => { try { this.getUIContext().getRouter().back() } catch (_e) {} })
            Column({ space: 4 }) {
              Text('录音').fontSize(25).fontWeight(FontWeight.Bold).fontColor('#18221E')
              Text(this.statusText).fontSize(12).fontColor('#87928D')
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
          }
          .width('100%')
          .margin({ top: 10, bottom: 18 })

          // 状态卡片
          Column({ space: 8 }) {
            Row({ space: 12 }) {
              Column({ space: 3 }) {
                Text(this.status?.recording === true ? (this.status?.realtime === true ? '● 实时录音中' : '● 录音中') : '○ 未在录音')
                  .fontSize(17).fontWeight(FontWeight.Bold)
                  .fontColor(this.status?.recording === true ? '#D9483B' : '#18221E')
                if (this.status?.recording === true) {
                  Text(`开始于 ${this.formatTime(this.status?.startTime ?? 0)} · 已录 ${this.status?.duration ?? 0} 秒`)
                    .fontSize(12).fontColor('#87928D')
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Button(this.status?.recording === true ? '停止' : '开始录音')
                .fontSize(14).backgroundColor(this.status?.recording === true ? '#D9483B' : '#0C9B6C')
                .onClick(() => this.toggleRecording())
                .enabled(!this.busy && this.status !== null)
            }
            .width('100%')
            Button(this.status?.recording === true && this.status?.realtime === true ? '停止实时录音' : '开始实时录音')
              .fontSize(14).backgroundColor(this.status?.realtime === true ? '#D9483B' : '#0C9B6C')
              .onClick(() => this.toggleRealtimeRecording())
              .enabled(!this.busy && this.status !== null && !(this.status?.recording === true && this.status?.realtime !== true))
            if (this.status?.realtime === true || this.realtimePackets > 0) {
              Text(`实时音频 ${this.realtimePackets} 包 / ${this.realtimeBytes} 字节 / 序号 ${this.realtimeSequence}`)
                .fontSize(12).fontColor('#0C9568').width('100%')
            }
            Divider().strokeWidth(1).color('#EDF0EE')
            Row({ space: 16 }) {
              Text(`总容量 ${this.status?.totalCapacity ?? '-'}`).fontSize(12).fontColor('#87928D')
              Text(`剩余 ${this.status?.remainingCapacity ?? '-'}`).fontSize(12).fontColor('#87928D')
            }
            .width('100%')
          }
          .padding(16)
          .borderRadius(14)
          .backgroundColor('#FFFFFF')
          .width('100%')

          // 操作行
          Row({ space: 10 }) {
            Button('刷新状态').fontSize(14).backgroundColor('#EDF0EE').fontColor('#26312C')
              .layoutWeight(1).onClick(() => this.refreshStatus())
            Button('格式化录音区').fontSize(14).backgroundColor('#EDF0EE').fontColor('#D9483B')
              .layoutWeight(1).onClick(() => this.confirmFormat())
          }
          .width('100%')
          .margin({ top: 12, bottom: 16 })

          // 文件列表
          Row() {
            Text('录音文件').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#18221E')
            Blank()
            Text(this.filesLoading ? '加载中...' : `共 ${this.files.length} 条`)
              .fontSize(12).fontColor('#87928D')
            Text('↻').fontSize(20).fontColor('#0C9568').margin({ left: 12 })
              .onClick(() => this.refreshFiles())
          }
          .width('100%')
          .margin({ bottom: 8 })

          if (this.files.length === 0 && !this.filesLoading) {
            Text('设备上没有录音文件，点击 ↻ 刷新')
              .fontSize(13).fontColor('#87928D').width('100%').textAlign(TextAlign.Center)
              .padding(20)
          }

          ForEach(this.files, (item: RecordFileItemBean) => {
            Column({ space: 8 }) {
              Row({ space: 8 }) {
                Column({ space: 3 }) {
                  Text(`ID ${item.fileId}`).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#18221E')
                  Text(`${this.formatTime(item.timestamp)} · ${item.duration} 秒 · ${this.formatSize(item.fileSize)}`)
                    .fontSize(12).fontColor('#87928D')
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                Button('下载').fontSize(13).backgroundColor('#0C9B6C')
                  .onClick(() => this.downloadFile(item))
                Button('删除').fontSize(13).backgroundColor('#EDF0EE').fontColor('#D9483B')
                  .onClick(() => this.confirmDelete(item))
              }
              .width('100%')
            }
            .padding(14)
            .borderRadius(14)
            .backgroundColor('#FFFFFF')
            .width('100%')
            .margin({ bottom: 8 })
          }, (item: RecordFileItemBean) => `${item.fileId}`)

          if (this.transferText.length > 0) {
            Text(this.transferText).fontSize(12).fontColor('#0C9568').width('100%')
              .padding({ top: 6, bottom: 20 })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .padding({ left: 18, right: 18, bottom: 30 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F7F5')
  }
}
