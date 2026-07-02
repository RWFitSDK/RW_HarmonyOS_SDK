import { promptAction } from '@kit.ArkUI';
import { BLE_ACTIVITY_START_INDEX, RwBleSdk, WORKOUT_BEGIN, WORKOUT_FINISH } from 'rw_ble_sdk';

@Entry
@Component
struct WorkoutTypePage {
  @State private loading: boolean = false
  @State private statusText: string = '读取当前运动状态中...'

  private readonly workoutNames: string[] = [
    '跑步', '跑步机', '户外跑步', '骑行', '游泳', '健走', '登山', '瑜伽', '动感单车', '篮球',
    '足球', '羽毛球', '马拉松', '室内步行', '自由锻炼', '田径', '体能训练', '举重', '拳击', '跳绳',
    '爬楼梯', '滑雪', '滑冰', '轮滑', '室内骑行', '呼啦圈', '高尔夫', '棒球', '舞蹈', '乒乓球',
    '曲棍球', '普拉提', '跆拳道', '手球', '街舞', '排球', '网球', '飞镖', '体操', '踏步',
    '椭圆机', '尊巴', '板球', '徒步旅行', '有氧运动', '划船机', '橄榄球', '仰卧起坐', '哑铃', '健身操',
    '空手道', '击剑', '武术', '太极拳', '飞盘', '射箭', '骑马', '保龄球', '冲浪', '垒球',
    '壁球', '帆船', '引体向上', '滑板', '蹦床', '钓鱼', '钢管舞', '广场舞', '爵士舞', '芭蕾舞',
    '迪斯科', '踢踏舞', '现代舞', '俯卧撑', '滑板车', '平板支撑', '桌球', '攀岩', '铁饼', '赛马',
    '摔跤', '跳高', '跳伞', '铅球', '跳远', '标枪', '链球', '深蹲', '压腿', '越野自行车',
    '越野摩托车', '赛艇', 'Crossfit', '水上自行车', '皮划艇', '槌球', '地板球', '泰拳', '回力球', '网球(双打)',
    '背部训练', '水上排球', '滑水', '登山机', '高强度间歇性训练', 'BODY COMBAT', 'BODY BALANCE', '全身抗阻力锻炼', '跆搏', '小轮车',
    '拉伸', '室内健身', '柔韧训练', '上肢训练', '下肢训练', '自由体操', '杠铃训练', '体能训练', '硬拉', '波比跳',
    '功能性训练', '腰腹训练', '桌式足球', '打猎', '立桨冲浪', '皮艇漂流', '摩托艇', '跑酷', '沙滩车', '滑翔伞',
    '冰壶', '滑雪板', '滑雪双板', '高山滑雪', '越野滑雪', '雪地摩托', '雪车', '雪橇', '墙球', '冰球',
    '藤球', '水球', '肚皮舞', '交际舞', '民族舞', '拉丁舞', '柔道', '踢拳', '放风筝', '拔河',
    '毽球', '卡巴迪', '赛车', '石子游戏', '捉人游戏'
  ]

  aboutToAppear(): void {
    this.refreshSportStatus()
  }

  build() {
    Stack() {
      Column({ space: 12 }) {
        Row() {
          Button('← 返回').type(ButtonType.Normal)
            .onClick(() => { try { this.getUIContext().getRouter().back() } catch (_e) {} })
          Text('Work out type').fontSize(24).fontWeight(FontWeight.Bold).margin({ left: 12 })
        }
        .width('100%')

        Text(this.statusText)
          .fontSize(13)
          .fontColor('#687076')
          .width('100%')
          .padding({ left: 2, right: 2 })

        List({ space: 8 }) {
          ForEach(this.workoutNames, (name: string, index: number) => {
            ListItem() {
              Row() {
                Text(name)
                  .fontSize(16)
                  .fontColor('#1F2937')
                  .layoutWeight(1)
                Text(`${BLE_ACTIVITY_START_INDEX + index}`)
                  .fontSize(12)
                  .fontColor('#9CA3AF')
              }
              .width('100%')
              .height(48)
              .padding({ left: 14, right: 14 })
              .backgroundColor('#FFFFFF')
              .borderRadius(8)
              .border({ width: 1, color: '#E5E7EB' })
            }
            .onClick(() => this.startWorkout(index))
          }, (name: string, index: number) => `${index}-${name}`)
        }
        .width('100%')
        .layoutWeight(1)
      }
      .padding(16)
      .width('100%')
      .height('100%')

      if (this.loading) {
        Column() {
          LoadingProgress().width(46).height(46).color('#FFFFFF')
          Text('处理中...').fontSize(14).fontColor('#FFFFFF').margin({ top: 8 })
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
      }
    }
    .width('100%')
    .height('100%')
  }

  private async refreshSportStatus(): Promise<void> {
    try {
      const res = await RwBleSdk.getSportStatus()
      const sport = res as SportControlRouteParams
      if (this.isInRunning(sport.status)) {
        this.statusText = `设备运动中: ${this.nameForSport(sport.sportType)}`
        this.goRunning(sport.sportType, sport.status)
      } else {
        this.statusText = '请选择运动类型'
      }
    } catch (e) {
      this.statusText = `读取运动状态失败: ${JSON.stringify(e)}`
    }
  }

  private async startWorkout(index: number): Promise<void> {
    if (this.loading) return
    const sportType: number = BLE_ACTIVITY_START_INDEX + index
    this.loading = true
    try {
      const current = await RwBleSdk.getSportStatus()
      const status = current as SportControlRouteParams
      if (this.isInRunning(status.status)) {
        this.showToast('设备已有运动进行中')
        this.goRunning(status.sportType, status.status)
        return
      }
      await RwBleSdk.controlSport(sportType, WORKOUT_BEGIN)
      this.goRunning(sportType, WORKOUT_BEGIN)
    } catch (e) {
      this.showToast(`启动失败: ${JSON.stringify(e)}`)
    } finally {
      this.loading = false
    }
  }

  private isInRunning(status: number): boolean {
    return status >= WORKOUT_BEGIN && status < WORKOUT_FINISH
  }

  private nameForSport(sportType: number): string {
    const index = sportType - BLE_ACTIVITY_START_INDEX
    return index >= 0 && index < this.workoutNames.length ? this.workoutNames[index] : `类型${sportType}`
  }

  private goRunning(sportType: number, controlType: number): void {
    try {
      this.getUIContext().getRouter().pushUrl({
        url: 'pages/WorkoutRunningPage',
        params: { sportType: sportType, controlType: controlType }
      })
    } catch (_e) {}
  }

  private showToast(msg: string): void {
    try {
      promptAction.showToast({ message: msg, duration: 2000 })
    } catch (_e) {}
  }
}

interface SportControlRouteParams {
  sportType: number
  status: number
  controlType?: number
}
