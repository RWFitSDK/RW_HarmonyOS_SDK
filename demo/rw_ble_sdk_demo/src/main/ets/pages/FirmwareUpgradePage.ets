import { common } from '@kit.AbilityKit';
import { promptAction } from '@kit.ArkUI';
import { picker } from '@kit.CoreFileKit';
import fs from '@ohos.file.fs';
import { FirmVersionBean, RwBleSdk } from 'rw_ble_sdk';

@Entry
@Component
struct FirmwareUpgradePage {
  @State private connected: boolean = false
  @State private deviceModel: string = '--'
  @State private firmwareVersion: string = '--'
  @State private selectedFileName: string = ''
  @State private selectedFileSize: string = ''
  @State private selectedFilePath: string = ''
  @State private upgrading: boolean = false
  @State private progress: number = 0
  @State private statusText: string = '等待选择固件'

  private context(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext
  }

  aboutToAppear(): void {
    this.connected = RwBleSdk.isBleConnected()
    if (this.connected) this.refreshFirmwareInfo()
  }

  build() {
    Stack() {
      Scroll() {
        Column({ space: 0 }) {
          Row({ space: 12 }) {
            Text('‹').fontSize(34).fontColor('#26312C').width(38)
              .onClick(() => { try { this.getUIContext().getRouter().back() } catch (_e) {} })
            Column({ space: 4 }) {
              Text('固件升级').fontSize(26).fontWeight(FontWeight.Bold).fontColor('#18221E')
              Text('选择厂家提供的 .bin 固件文件').fontSize(13).fontColor('#87928D')
            }
            .alignItems(HorizontalAlign.Start)
          }
          .width('100%')
          .margin({ top: 12, bottom: 22 })

          Column({ space: 8 }) {
            Text('升级前请确认').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#AE632B').width('100%')
            Text('仅选择设备厂家提供并确认适用于当前设备的 .bin 文件。错误固件可能导致设备无法使用。')
              .fontSize(13).fontColor('#9B7659').lineHeight(21).width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .backgroundColor('#FFF8EE')
          .border({ width: 1, color: '#F0D5B9' })
          .borderRadius(20)

          this.SectionTitle('当前设备')
          Column() {
            this.InfoRow('连接状态', this.connected ? '已连接' : '未连接', this.connected)
            Divider().strokeWidth(1).color('#EDF1EF')
            this.InfoRow('设备型号', this.deviceModel, false)
            Divider().strokeWidth(1).color('#EDF1EF')
            this.InfoRow('固件版本', this.firmwareVersion, false)
          }
          .width('100%')
          .padding({ left: 18, right: 18 })
          .backgroundColor('#FFFFFF')
          .borderRadius(20)

          this.SectionTitle('升级文件')
          if (this.selectedFilePath.length > 0) {
            Row({ space: 14 }) {
              Text('BIN').fontSize(13).fontWeight(FontWeight.Bold).fontColor('#13845F')
                .textAlign(TextAlign.Center).width(48).height(48).backgroundColor('#E3F2EC').borderRadius(14)
              Column({ space: 5 }) {
                Text(this.selectedFileName).fontSize(15).fontWeight(FontWeight.Medium).fontColor('#26312C')
                  .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(this.selectedFileSize).fontSize(12).fontColor('#82908A')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('更换').fontSize(13).fontColor('#0C9568').onClick(() => this.selectBinFile())
            }
            .width('100%')
            .padding(18)
            .backgroundColor('#F0FAF6')
            .borderRadius(20)
          } else {
            Column({ space: 10 }) {
              Text('BIN').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#13845F')
                .textAlign(TextAlign.Center).width(58).height(58).backgroundColor('#E3F2EC').borderRadius(18)
              Text('请选择 .bin 固件文件').fontSize(17).fontWeight(FontWeight.Bold).fontColor('#26312C')
              Text('从系统文件中选择一个厂家提供的固件').fontSize(13).fontColor('#8C9792')
              Button('选择 BIN 文件').fontSize(14).fontColor('#FFFFFF').backgroundColor('#0C9568').borderRadius(22)
                .margin({ top: 8 }).onClick(() => this.selectBinFile())
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .padding({ top: 30, bottom: 30 })
            .backgroundColor('#FFFFFF')
            .borderRadius(20)
          }

          Column({ space: 12 }) {
            Row() {
              Text(this.statusText).fontSize(13).fontColor('#69766F').layoutWeight(1)
              Text(`${this.progress}%`).fontSize(13).fontColor('#0C9568')
            }
            .width('100%')
            Progress({ value: this.progress, total: 100, type: ProgressType.Linear })
              .color('#0C9568').backgroundColor('#E8EFEC').height(8).width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding(18)
          .backgroundColor('#FFFFFF')
          .borderRadius(20)
          .margin({ top: 22 })

          Button(this.upgrading ? '正在升级' : '开始固件升级')
            .enabled(this.connected && this.selectedFilePath.length > 0 && !this.upgrading)
            .fontSize(16)
            .fontColor('#FFFFFF')
            .backgroundColor('#0C9568')
            .borderRadius(24)
            .width('100%')
            .margin({ top: 20, bottom: 30 })
            .onClick(() => this.startUpgrade())
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 18, right: 18 })
      }
      .height('100%')

      if (this.upgrading) {
        Column({ space: 12 }) {
          LoadingProgress().width(50).height(50).color('#FFFFFF')
          Text(`固件升级中 ${this.progress}%`).fontSize(15).fontColor('#FFFFFF')
          Text('请保持设备靠近并勿退出应用').fontSize(12).fontColor('#DDE8E3')
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
        .backgroundColor('#8A000000')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F7F5')
  }

  @Builder
  private SectionTitle(title: string) {
    Text(title).fontSize(19).fontWeight(FontWeight.Bold).fontColor('#1C2823').width('100%')
      .margin({ top: 27, bottom: 13 })
  }

  @Builder
  private InfoRow(title: string, value: string, highlight: boolean) {
    Row() {
      Text(title).fontSize(14).fontColor('#727D78').layoutWeight(1)
      Text(value).fontSize(14).fontColor(highlight ? '#0C9568' : '#27322D').maxLines(1)
    }
    .width('100%')
    .height(54)
  }

  private async refreshFirmwareInfo(): Promise<void> {
    try {
      const info: FirmVersionBean = await RwBleSdk.getFirmwareVersion()
      this.deviceModel = info.deviceClazz ?? '--'
      this.firmwareVersion = info.deviceNo ?? '--'
    } catch (_e) {}
  }

  private async selectBinFile(): Promise<void> {
    if (this.upgrading) return
    try {
      const documentPicker = new picker.DocumentViewPicker(this.context())
      const options = new picker.DocumentSelectOptions()
      options.maxSelectNumber = 1
      options.fileSuffixFilters = ['固件文件|.bin']
      const uris = await documentPicker.select(options)
      if (uris.length === 0) return
      const uri = uris[0]
      const fileName = this.fileNameFromUri(uri)
      if (!fileName.toLowerCase().endsWith('.bin')) {
        this.showToast('请选择 .bin 固件文件')
        return
      }
      const destination = `${this.context().cacheDir}/rw_ota_${Date.now()}.bin`
      const sourceFile = fs.openSync(uri, fs.OpenMode.READ_ONLY)
      const targetFile = fs.openSync(destination, fs.OpenMode.CREATE | fs.OpenMode.TRUNC | fs.OpenMode.WRITE_ONLY)
      try {
        fs.copyFileSync(sourceFile.fd, targetFile.fd)
      } finally {
        fs.closeSync(sourceFile.fd)
        fs.closeSync(targetFile.fd)
      }
      const size = fs.statSync(destination).size
      this.selectedFileName = fileName
      this.selectedFileSize = this.formatSize(size)
      this.selectedFilePath = destination
      this.progress = 0
      this.statusText = '固件已选择，可以开始升级'
    } catch (error) {
      this.showToast(`选择文件失败: ${JSON.stringify(error)}`)
    }
  }

  private startUpgrade(): void {
    if (!this.connected || this.selectedFilePath.length === 0 || this.upgrading) return
    this.upgrading = true
    this.progress = 0
    this.statusText = '正在传输固件'
    RwBleSdk.ringOtaWithFileData(this.selectedFilePath, {
      onProgress: (value: number) => {
        const percent = value <= 1 ? Math.floor(value * 100) : Math.floor(value)
        this.progress = Math.min(100, Math.max(0, percent))
      },
      onSuccess: () => {
        this.progress = 100
        this.upgrading = false
        this.statusText = '固件数据发送完成'
        this.showToast('升级完成，设备可能会自动重启')
      },
      onError: (code: number) => {
        this.upgrading = false
        this.statusText = `升级失败 (${code})`
        this.showToast(`升级失败: ${code}`)
      }
    })
  }

  private fileNameFromUri(uri: string): string {
    const clean = uri.split('?')[0]
    const name = clean.substring(clean.lastIndexOf('/') + 1)
    try { return decodeURIComponent(name) } catch (_e) { return name }
  }

  private formatSize(size: number): string {
    if (size >= 1024 * 1024) return `${(size / 1024 / 1024).toFixed(2)} MB`
    if (size >= 1024) return `${(size / 1024).toFixed(1)} KB`
    return `${size} B`
  }

  private showToast(message: string): void {
    try { promptAction.showToast({ message, duration: 2500 }) } catch (_e) {}
  }
}
