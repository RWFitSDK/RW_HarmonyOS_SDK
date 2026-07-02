# RW BLE HarmonyOS SDK使用说明文档

## 1. 简介

本文档主要对SDK里所提供的功能接口与使用场景进行解释说明。

此文档仅适用于RW公司的蓝牙设备.

#### 1.1 适用平台与语言

- HarmonyOS NEXT（API 12+），语言 ArkTS.

#### 1.2 相关术语

-  App: 本⽂指的是⼿机端或平板电脑上运⾏的应⽤程序;
-  设备: 本⽂指的是可穿戴式硬件设备:如⼿表,戒指等;
-  上传: 指的是设备向App发送数据;
-  下发: 指的是App向设备发送数据;

#### 1.3 注意事项

1. 使用此SDK时最好结合示例工程 `rw_ble_sdk_demo` 使用; 参考例子只需关注 ScanPage 与 MainPage 两个页面代码即可.

2. `RwBleSdk` 指令操作分两种模式:
   - **一问一答型**（GET/SET类）: 直接使用 `await` 获取结果，无需手动订阅和取消;
   - **持续推送型**（实时数据/同步流）: 使用回调订阅，返回取消函数，不再使用时调用取消即可;



## 2. 快速开始（Quick Start）

**第1步: 获取最新版本的DevEco Studio**

要想使用 RW BLE SDK for HarmonyOS 开发项目，您需要安装 DevEco Studio.

**第2步: 添加依赖库**

1. 在项目 `oh-package.json5` 中添加 HAR 依赖

```json
{
  "dependencies": {
    "rw_ble_sdk": "file:../rw_ble_sdk"
  }
}
```



**第3步: 声明蓝牙权限**

在 `module.json5` 中声明权限:

```json
"requestPermissions": [
  {
    "name": "ohos.permission.ACCESS_BLUETOOTH",
    "reason": "$string:reason_bluetooth",
    "usedScene": {}
  }
]
```

> HarmonyOS 统一为 `ACCESS_BLUETOOTH` 单一权限，无需像 Android 分别申请 SCAN/CONNECT/LOCATION.

**第4步: 初始化SDK**

```typescript
import { RwBleSdk } from 'rw_ble_sdk'

RwBleSdk.initSDK(getContext(this))
```

> [!CAUTION]
>
> 会默认保存蓝牙部分日志文件, 保存在应用沙箱 `files/logger/devices/` 文件夹下. 可 `RwBleSdk.setLogEnable(false)` 关闭.



## 3. 接口说明（API Reference）

### 3.1 设备搜索与连接, 绑定与重连

##### 3.1.1 搜索蓝牙

>  接口说明: 搜索蓝牙设备需使用 `RwBleSdk.startScan`;

```typescript
import { RwBleSdk, RwBleDevice } from 'rw_ble_sdk'

// 开始搜索
RwBleSdk.startScan({
  onScanDevice(device: RwBleDevice) {
    // 搜索到的蓝牙设备
    console.log(`发现设备: ${device.name} rssi:${device.rssi}`)
  },
  onScanFinish() {
    console.log('扫描结束')
  },
  onError(code: number, e: Error) {
    console.error(`扫描错误: ${code}`)
  }
})

// 停止搜索
RwBleSdk.stopScan()
```

##### 3.1.2 停止搜索

> 接口说明: 停止搜索蓝牙设备

```typescript
RwBleSdk.stopScan()
```



##### 3.1.3 连接设备与状态监听

> 接口说明: 连接指定设备,并监听设备连接状态.

```typescript
// 1. 注册连接回调
RwBleSdk.setConnectBleCallback({
  onRingConnecting() {
    console.log('连接中...')
  },
  onRingConnected() {
    console.log('已连接')
  },
  onRingConnectFailed(reason: string) {
    console.log(`连接失败: ${reason}`)
  },
  onRingDisconnected(reason: string) {
    console.log(`已断开: ${reason}`)
  },
  onRingDidFunctionMenu(menu: SupportMenuBean) {
    // 业务指令在此之后调用
    console.log('功能表获取成功，可以开始业务操作')
  }
})

// 2. 连接设备
RwBleSdk.connectDeviceWithModel(bleDevice)
```

`RingConnectBleCallback` 接口说明:

| 方法                  | 说明                                                 |
| :-------------------- | ---------------------------------------------------- |
| onRingConnecting      | 连接中                                               |
| onRingConnected       | connectDeviceWithModel后,连接成功会返回.             |
| onRingConnectFailed   | 连接失败会回调                                       |
| onRingDisconnected    | 蓝牙断开会回调                                       |
| onRingDidFunctionMenu | 成功获取设备配置表后会返回;业务操作应该在此之后操作. |

>  [!TIP]
>
> 连接后, 业务操作应该在 `onRingDidFunctionMenu` 之后才进行操作.
>
> `RwBleSdk.notifyConnected()` 与 `RwBleSdk.notifyDisconnected(reason)` 是 SDK 内部连接层桥接方法，业务侧通常不需要主动调用；文档保留说明以便后续和 Android 连接章节对齐。



##### 3.1.4 断开连接设备

> 接口说明: 断开正在连接的设备

```typescript
RwBleSdk.disconnect()
```

当前连接状态可通过 `RwBleSdk.isBleConnected(): boolean` 获取。

##### 3.1.5 本地绑定与自动重连,解绑

> [!IMPORTANT]
>
> HarmonyOS本地绑定,自动重连需自行实现, 本SDK不提供此功能;可以连接成功后,保存设备信息与配置表,方便页面显示与重连.

已保存设备信息后，可调用 `RwBleSdk.reconnectDevice(device: RwBleDevice): void` 发起重连。



##### 3.1.6 设备功能配置表

>  [!IMPORTANT]
>
> 因设备型号多, 支持的功能不同,所以引入功能表信息,可查询设备功能支持情况. 具体参考 SupportMenuBean 类. 可根据业务自行保存功能表内容. 

`onRingDidFunctionMenu(menu: SupportMenuBean)`

已连接后也可通过 `RwBleSdk.getSupportMenu(): SupportMenuBean | null` 获取当前缓存的配置表。

SupportMenuBean 属性定义:

| SupportMenuBean属性         | 说明                     |
| --------------------------- | ------------------------ |
| isPushMsgEnableSwitch       | 是否启用消息控制开关     |
| isAlarm                     | 是否支持闹钟             |
| isBrightScreenSleepTime     | 是否支持屏幕睡眠时间设置 |
| isBrightScreenTime          | 是否支持亮屏时长         |
| isNewSport                  | 是否支持多运动           |
| isRememberSwitch            | 是否支持Muslim赞念开关   |
| isSupportHrReminder         | 是否支持HR报警提示功能   |
| isSupportBoReminder         | 是否支持SP02报警提示功能 |
| isSupportMotoVibrationLevel | 是否支持马达震动提醒     |
| isSupportAlarmVibrationDuration | 是否支持闹钟震动时长设置 |
| isSupportVibrationInterval  | 是否支持震动间隔时长设置 |
| isStep                      | 是否支持计步             |
| isHr                        | 是否支持心率             |
| isBloodPress                | 是否支持血压             |
| isSleep                     | 是否支持睡眠             |
| isBloodOxy                  | 是否支持血氧             |
| isHrv                       | 是否支持心率变异性       |
| isPressure                  | 是否支持压力             |
| isBloodSugar                | 是否支持血糖             |
| isMuslimCountData           | 是否支持赞念             |
| isDataTypeTemperature       | 是否支持体温             |
| isSupportMuslimTimeDisplayMode | 是否支持Muslim时间显示模式 |
| isSupportSensorRawPPG       | 是否支持获取PPG原始数据   |
| isSupportPPGMonitoring      | 是否支持PPG定时监测       |
| isSupportTemperatureMonitoring | 是否支持温度定时监测    |
| isSupportCountReminder      | 是否支持计数提醒间隔设置 |
| isSupportSensorRawACC       | 是否支持获取ACC原始数据   |
| isSupportSensorRawPPGRed    | 是否支持获取PPG Red原始数据 |
| isSupportSensorRawIR        | 是否支持获取IR红外原始数据  |
| isSupportSensorRawSleep     | 是否支持睡眠实时数据       |
| isSupportFallDetect         | 是否支持跌落提醒           |
| isSupportRecording          | 是否支持录音功能           |



### 3.2 设备功能操作

#### 3.2.1 基础功能指令接口

##### 3.2.1.1 Get SDK Version

> 获取SDK版本号.

方法说明: 

`RwBleSdk.getSDKVersion(): string`

调用示例:

```typescript
console.log(RwBleSdk.getSDKVersion())
```

##### 3.2.1.2 设置用户信息

> 用户信息设置与计步卡路里,距离有关; 设备初始化时性别为1, 年龄 18, 身高170cm, 体重 65 kg.

方法说明: 

`RwBleSdk.setUserInfo(person: PersonBean): Promise<void>`

参数说明:

| 参数   | 类型       | 说明 | 值                                                           |
| ------ | ---------- | ---- | ------------------------------------------------------------ |
| person | PersonBean | 类   | gender: 性别（0.女 1.男)<br>height: 身高cm,浮点型<br>weight: 体重kg,浮点型<br/>age: 年龄 |

调用示例:

```typescript
const person: PersonBean = {
  gender: 1,
  height: 170.5,
  weight: 80,
  age: 20,
  measureUnit: 0
}

try {
  await RwBleSdk.setUserInfo(person)
  console.log('用户信息设置成功')
} catch (e) {
  console.error('用户信息设置失败', e.message)
}
```



##### 3.2.1.3 获取设备信息

> 接口说明: 获取固件型号,固件版本号,UI版本号.

方法说明:

`RwBleSdk.getFirmwareVersion(): Promise<FirmVersionBean>`

`RwBleSdk.getMacAddress(): Promise<string>`

调用示例:

```typescript
try {
  const info = await RwBleSdk.getFirmwareVersion()
  console.log(`设备型号: ${info.deviceClazz}`)
  console.log(`固件版本: ${info.deviceNo}`)
  console.log(`UI版本: ${info.uiVersion}`)
  console.log(`屏幕: ${info.screenWidth}x${info.screenHeight}`)

  const mac = await RwBleSdk.getMacAddress()
  console.log(`设备MAC: ${mac}`)
} catch (e) {
  console.error('获取设备信息失败', e.message)
}
```

FirmVersionBean:

```typescript
interface FirmVersionBean {
  deviceClazz: string   // 设备型号
  deviceNo: string      // 设备版本号
  screenType: number    // 0方 1圆
  screenWidth: number   // 设备宽
  screenHeight: number  // 设备高
  uiVersion: string     // UI版本号
}
```



##### 3.2.1.4 **获取电量**

> 接口说明: app获取设备电量.

方法说明:

`RwBleSdk.getPower(): Promise<PowerBean>`

调用示例:

```typescript
try {
  const power = await RwBleSdk.getPower()
  console.log(`电量: ${power.power}%`)
  console.log(`电压: ${power.voltage}`)
} catch (e) {
  console.error('获取电量失败', e.message)
}
```

PowerBean:

```typescript
interface PowerBean {
  power: number     // 电量 0-100
  voltage?: number  // 电压
}
```



##### 3.2.1.5 获取与设置视频控制开关

> 设置是否开启戒指手势控制刷视频; 此功能需配对蓝牙HID.

方法说明:

`RwBleSdk.setVideoHid(bean: VideoHidBean): Promise<void>`

`RwBleSdk.getVideoHid(): Promise<Object>`

参数说明:

| 参数         | 类型         | 说明 | 值                                           |
| ------------ | ------------ | ---- | -------------------------------------------- |
| videoHidBean | VideoHidBean | 类   | hidOpen: 0.关闭 1.视频打开 2. book 3. music |

调用示例:

```typescript
// 设置视频控制开关
await RwBleSdk.setVideoHid({ hidOpen: 1 })

// 获取视频控制开关
const hid = await RwBleSdk.getVideoHid()
console.log(`视频控制: ${hid.hidOpen}`)
```

##### 3.2.1.6 获取与设置LED亮屏强度

> 配置表属性: `isLEDLight`

方法说明:

`RwBleSdk.setRingLedLevel(bean: BrightScreenLedBean): Promise<void>`

`RwBleSdk.getRingLedLevel(): Promise<Object>`

参数说明:

| 参数             | 类型                | 说明 | 值                                                           |
| ---------------- | ------------------- | ---- | ------------------------------------------------------------ |
| brightScreenBean | BrightScreenLedBean | 类   | isOpen: false为off,true为(1-3Level)<br>lcdLevel: 1微光, 2柔光, 3强光 |

调用示例:

```typescript
// 获取LED亮屏强度
const led = await RwBleSdk.getRingLedLevel()
console.log(`LED等级: ${led.lcdLevel}`)

// 设置LED亮屏强度
await RwBleSdk.setRingLedLevel({ isOpen: true, lcdLevel: 3 })
```



##### 3.2.1.7 获取与设置佩戴位置

> 配置表属性: `isWearDir`

方法说明:

`RwBleSdk.setRingWearHand(isRight: boolean): Promise<void>`

`RwBleSdk.getRingWearDir(): Promise<Object>`

调用示例:

```typescript
// 获取佩戴位置
const dir = await RwBleSdk.getRingWearDir()
console.log(`佩戴: ${dir === 0 ? '左手' : '右手'}`)

// 设置佩戴位置
await RwBleSdk.setRingWearHand(false) // false左手, true右手
```



##### 3.2.1.8 启动与关闭拍照

> 启动拍照功能后,设备可通过手势控制app自定义相机拍照.
>
> 配置表属性: `isTakePhoto`

方法说明:

`RwBleSdk.controlTakePhoto(status: number): Promise<void>`

`RwBleSdk.onTakePhotoEvent(cb: (value: Object) => void): () => void`

调用示例:

```typescript
// 订阅设备拍照事件
const unsub = RwBleSdk.onTakePhotoEvent((value) => {
  // value 为设备主动上报的拍照事件数据
  console.log(`拍照事件: ${JSON.stringify(value)}`)
})

// 启动拍照模式
await RwBleSdk.controlTakePhoto(1)

// 退出时关闭拍照并取消订阅
await RwBleSdk.controlTakePhoto(0)
unsub()
```

##### 3.2.1.9 查找设备

> 调用查找后设备灯或屏幕会亮.

方法说明:

`RwBleSdk.controlFindDevice(): void`

调用示例:

```typescript
RwBleSdk.controlFindDevice()
```

##### 3.2.1.10 关机,恢复出厂设置

方法说明:

`RwBleSdk.setPowerOff(type: number): Promise<void>`

参数说明:

| 参数 | 类型   | 说明 | 值                                             |
| ---- | ------ | ---- | ---------------------------------------------- |
| type | number | 整形 | 关机: CONTROL_DEVICE_POWER_OFF<br>恢复出厂: CONTROL_DEVICE_RECOVERY |

调用示例:

```typescript
import { Constants } from 'rw_ble_sdk'

// 关机
await RwBleSdk.setPowerOff(Constants.CONTROL_DEVICE_POWER_OFF)

// 恢复出厂
await RwBleSdk.setPowerOff(Constants.CONTROL_DEVICE_RECOVERY)
```

##### 3.2.1.11 闹钟

###### 3.2.1.11.1 获取已设置闹钟

> 配置表属性: `isAlarm`

方法说明:

`RwBleSdk.getAlarmRemind(): Promise<Object>`

调用示例:

```typescript
const alarms = await RwBleSdk.getAlarmRemind()
console.log(`闹钟: ${JSON.stringify(alarms)}`)
```



###### 3.2.1.11.2 设置闹钟

> **当前协议不支持单独修改闹钟，任何单个闹钟的开关或删除操作，均需重新下发全部闹钟配置。**

方法说明:

`RwBleSdk.setAlarmRemind(alarms: AlarmRemainderBean[]): Promise<void>`

`RwBleSdk.setAlarm(alarms: AlarmRemainderBean[]): Promise<void>`

参数说明:

| 参数   | 类型                 | 说明     | 值                                                           |
| ------ | -------------------- | -------- | ------------------------------------------------------------ |
| alarms | AlarmRemainderBean[] | 闹钟数组 | isOpen: true开/false关<br>repeatModel: number[7] 周日至周六,要重复的对应置1<br>startHour: 闹钟开始时<br>startMin: 闹钟开始分<br>alarmTag: 设置为空字符串 |

调用示例:

```typescript
const alarms: AlarmRemainderBean[] = [
  {
    alarmTag: '',
    repeatModel: [0, 1, 1, 1, 1, 1, 0], // 周一至周五
    startHour: 7,
    startMin: 0,
    isOpen: true,
    alarmId: 0
  },
  {
    alarmTag: '',
    repeatModel: [0, 0, 0, 0, 0, 0, 0], // 单次
    startHour: 8,
    startMin: 30,
    isOpen: true,
    alarmId: 1
  }
]

await RwBleSdk.setAlarmRemind(alarms)
// setAlarm 与 setAlarmRemind 等价，保留给后续与 Android 章节命名对齐使用
```



###### 3.2.1.11.3 删除所有闹钟

方法说明:

`RwBleSdk.deleteAllAlarmRemind(): Promise<void>`

```typescript
await RwBleSdk.deleteAllAlarmRemind()
```

##### 3.2.1.12 震动次数设置与获取

> 配置表属性: `isSupportMotoVibrationLevel`

方法说明: 

`RwBleSdk.setVibrationCount(level: number, count: number): Promise<void>`

`RwBleSdk.getVibrationCount(): Promise<Object>`

参数说明:

| 参数  | 类型   | 说明 | 值                                                        |
| ----- | ------ | ---- | --------------------------------------------------------- |
| level | number | 整形 | 震动强度, 0:关闭 1:低 2:中 3:高; *未定义此功能的可忽略* |
| count | number | 整形 | 震动次数可以被设置(0-6次)，初始默认2次.设置0次不震动      |

调用示例:

```typescript
// 设置
await RwBleSdk.setVibrationCount(1, 2) // 震动次数2次

// 获取
const vibration = await RwBleSdk.getVibrationCount()
console.log(`震动次数: ${vibration.count}`)
```



##### 3.2.1.13 屏幕睡眠模式设置与获取

>  配置表属性: `isBrightScreenSleepTime`

方法说明: 

`RwBleSdk.setRingBrightScreenSleepTime(bean: BrightScreenTimeBean): Promise<void>`

`RwBleSdk.getRingBrightScreenSleepTime(): Promise<Object>`

参数说明:

| BrightScreenTimeBean参数 | 类型    | 说明                     |
| ------------------------ | ------- | ------------------------ |
| isOpen                   | boolean | 开关打开或关闭           |
| startHour                | number  | 开始时间小时             |
| startMin                 | number  | 开始时间分钟             |
| endHour                  | number  | 结束时间小时             |
| endMin                   | number  | 结束时间分钟             |

调用示例:

```typescript
// 设置
await RwBleSdk.setRingBrightScreenSleepTime({
  isOpen: true,
  startHour: 20,  // 晚上8点至早上8点睡眠
  startMin: 0,
  endHour: 8,
  endMin: 0
})

// 获取
const sleepTime = await RwBleSdk.getRingBrightScreenSleepTime()
console.log(`睡眠模式: ${sleepTime.isOpen} ${sleepTime.startHour}:${sleepTime.startMin}-${sleepTime.endHour}:${sleepTime.endMin}`)
```

##### 3.2.1.14 消息与来电

###### 3.2.1.14.1 消息推送

>  APP主动向设备推送消息通知(非ANCS), 消息开关由APP自行控制.

方法说明: 

`RwBleSdk.setPushMsg(msg: MsgPushBean): void`

调用示例:

```typescript
RwBleSdk.setPushMsg({
  appId: 'com.ten.wenxin',
  title: '微信',
  content: '你好'
})
```

###### 3.2.1.14.2 来电控制

> 设备端触发接听或挂断来电时, APP需监听设备指令并执行对应电话操作.

方法说明:

`RwBleSdk.controlPhone(type: number): void`

参数说明:

| 参数 | 类型   | 说明         | 值                  |
| ---- | ------ | ------------ | ------------------- |
| type | number | 来电控制类型 | 0: 接听<br>1: 挂断 |

调用示例:

```typescript
// 接听来电
RwBleSdk.controlPhone(0)

// 挂断来电
RwBleSdk.controlPhone(1)
```

###### 3.2.1.14.3 音乐控制

> 设备端触发音乐控制(播放/暂停/上一曲/下一曲等)时, APP需监听设备指令并执行对应操作.

方法说明:

`RwBleSdk.onMusicControl(cb: (value: Object) => void): () => void`

返回值说明:

| 值   | 说明     |
| ---- | -------- |
| 1    | 播放     |
| 2    | 暂停     |
| 3    | 上一曲   |
| 4    | 下一曲   |
| 5    | 音量加   |
| 6    | 音量减   |

调用示例:

```typescript
const unsub = RwBleSdk.onMusicControl((value) => {
  console.log(`音乐控制事件: ${JSON.stringify(value)}`)
})

// 不再使用时
unsub()
```

##### 3.2.1.15 获取与设置赞念是否打开

>  配置表属性: `isRememberSwitch`

方法说明: 

`RwBleSdk.setMuslimCountSwitch(status: number): Promise<void>`

`RwBleSdk.getMuslimCountSwitch(): Promise<Object>`

参数说明:

| 参数   | 类型   | 说明 | 值                 |
| ------ | ------ | ---- | ------------------ |
| status | number |      | 0: 关闭<br>1: 打开 |

调用示例:

```typescript
// 设置
await RwBleSdk.setMuslimCountSwitch(1)

// 获取
const status = await RwBleSdk.getMuslimCountSwitch()
console.log(`赞念开关: ${status === 1 ? '开' : '关'}`)
```



##### 3.2.1.16 获取与设置心率/血氧报警配置

>  配置表属性: `isSupportHrReminder`

方法说明: 

`RwBleSdk.getHrAlert(): Promise<Object>`

`RwBleSdk.setHrAlert(status: number, value: number, underValue: number): Promise<void>`

`RwBleSdk.getBoAlert(): Promise<Object>`

`RwBleSdk.setBoAlert(status: number, value: number): Promise<void>`

`RwBleSdk.onHrBoAlertEvent(cb: (value: Object) => void): () => void`

参数说明:

| 参数       | 类型   | 说明 | 值                                                           |
| ---------- | ------ | ---- | ------------------------------------------------------------ |
| status     | number |      | 1: 开, 0: 关                                                |
| value      | number |      | 超出报警值, 默认值为 心率超过160                             |
| underValue | number |      | 低于设置值报警; 如果获取到为0xff,代表不支持此项功能          |

实时报警事件 HrBoActualReminderBean 说明:

| 参数        | 类型   | 说明 | 值                                                   |
| ----------- | ------ | ---- | ---------------------------------------------------- |
| type        | number |      | 0: 心率超出报警, 1: 血氧报警, 2: 心率低于报警        |
| remindValue | number |      | 报警值                                               |

调用示例:

```typescript
// 设置心率报警
await RwBleSdk.setHrAlert(1, 140, 0xff)

// 获取心率报警配置
const hrAlert = await RwBleSdk.getHrAlert()

// 监听报警事件
const unsub = RwBleSdk.onHrBoAlertEvent((value) => {
  const alert = value as HrBoActualReminderBean
  if (alert.type === 0) console.log(`心率超出报警: ${alert.remindValue}`)
  if (alert.type === 1) console.log(`血氧报警: ${alert.remindValue}`)
  if (alert.type === 2) console.log(`心率低于报警: ${alert.remindValue}`)
})
```



##### 3.2.1.17 获取与设置亮屏时长

>  配置表属性: `isBrightScreenTime`

方法说明: 

`RwBleSdk.getBrightScreenTime(): Promise<Object>`

`RwBleSdk.setBrightScreenTime(time: number): Promise<void>`

参数说明:

| 参数       | 类型   | 说明                                         |
| ---------- | ------ | -------------------------------------------- |
| time       | number | 亮屏时长,秒(s), 范围0-30s                   |

调用示例:

```typescript
// 设置亮屏10秒
await RwBleSdk.setBrightScreenTime(10)

// 获取
const bright = await RwBleSdk.getBrightScreenTime()
console.log(`亮屏时长: ${(bright as BrightScreenTimeBean).timeSecond}s`)
```



##### 3.2.1.18 获取与设置抬腕亮屏

>  配置表属性: `isRaiseBrightScreen`

方法说明: 

`RwBleSdk.getRaiseBrightScreen(): Promise<Object>`

`RwBleSdk.setRaiseBrightScreen(bean: BrightScreenBean): Promise<void>`

参数说明:

| 参数      | 类型    | 说明                   |
| --------- | ------- | ---------------------- |
| isOpen    | boolean | true:开启; false:关闭  |
| startHour | number  | 开始时间小时           |
| startMin  | number  | 开始时间分钟           |
| endHour   | number  | 结束时间小时           |
| endMin    | number  | 结束时间分钟           |

调用示例:

```typescript
// 设置
await RwBleSdk.setRaiseBrightScreen({
  isOpen: true,
  startHour: 8,
  startMin: 0,
  endHour: 20,
  endMin: 0
})

// 获取
const raise = await RwBleSdk.getRaiseBrightScreen()
console.log(`抬腕亮屏: ${raise.isOpen}`)
```



##### 3.2.1.19 设置时间格式12/24小时制

>  带屏显示时间的设备才有效.

方法说明: 

`RwBleSdk.setTimeFormat(type: number): Promise<void>`

设备时间同步可调用 `RwBleSdk.setDate(): Promise<void>`，payload 由 SDK 按当前系统时间生成。

参数说明:

| 参数 | 类型   | 说明                       |
| ---- | ------ | -------------------------- |
| type | number | 0: 24小时制<br>1: 12小时制 |

调用示例:

```typescript
await RwBleSdk.setTimeFormat(0) // 24小时制
```



##### 3.2.1.20 闹钟震动时长设置与获取

> 配置表属性: `isSupportAlarmVibrationDuration`

方法说明:

`RwBleSdk.setAlarmVibrationDuration(count: number): Promise<void>`

`RwBleSdk.getAlarmVibrationDuration(): Promise<Object>`

参数说明:

| 参数  | 类型   | 说明 | 值                                       |
| ----- | ------ | ---- | ---------------------------------------- |
| count | number | 整形 | 震动次数(0-6), 默认2次, 设置0次为不震动 |

调用示例:

```typescript
// 设置
await RwBleSdk.setAlarmVibrationDuration(2)

// 获取
const count = await RwBleSdk.getAlarmVibrationDuration()
console.log(`闹钟震动次数: ${count}`)
```



##### 3.2.1.21 触摸事件通知

> 设备触摸事件通知, 设备主动上报.

方法说明:

`RwBleSdk.onTouchEvent(cb: (value: Object) => void): () => void`

返回值说明:

| 字段      | 说明     | 值                                                    |
| --------- | -------- | ----------------------------------------------------- |
| keyType   | 按键类型 | 1: 触摸按键(默认), 2: 跌落(需开启跌落提醒3.2.1.24)    |
| touchType | 触摸类型 | 1: 单击, 2: 双击, 3: 三击, 4: 长按, 5: 甩动          |

调用示例:

```typescript
const unsub = RwBleSdk.onTouchEvent((value) => {
  console.log(`触摸事件: ${JSON.stringify(value)}`)
})

// 不再使用时
unsub()
```



##### 3.2.1.22 震动间隔时长设置与获取

> 配置表属性: `isSupportVibrationInterval`

方法说明:

`RwBleSdk.setVibrationInterval(intervalMs: number): Promise<void>`

`RwBleSdk.getVibrationInterval(): Promise<Object>`

参数说明:

| 参数       | 类型   | 说明 | 值                              |
| ---------- | ------ | ---- | ------------------------------- |
| intervalMs | number | 整形 | 间隔时长(100-1000ms), 默认500ms |

调用示例:

```typescript
// 设置
await RwBleSdk.setVibrationInterval(500)

// 获取
const interval = await RwBleSdk.getVibrationInterval()
console.log(`震动间隔: ${interval}ms`)
```



##### 3.2.1.23 心率校正(工厂测试)

> 发送校正指令后, 设备会返回两次: 第1次 result=0 表示校正中; 第2次 result非0 表示校正完成.

方法说明:

`RwBleSdk.startFactoryTest(testMode: number): Promise<number>`

调用示例:

```typescript
// 返回值为校正结果
const result = await RwBleSdk.startFactoryTest(0x15)
console.log(`心率校正结果: ${result}`)
```



##### 3.2.1.24 跌落提醒设置

> 配置表属性: `isSupportFallDetect`
>
> 开启后设备检测到跌落时会通过触摸事件通知(3.2.1.21)上报, keyType=2.

方法说明:

`RwBleSdk.setFallDetect(enable: number): Promise<void>`

`RwBleSdk.getFallDetect(): Promise<Object>`

参数说明:

| 参数   | 类型   | 说明         | 值                |
| ------ | ------ | ------------ | ----------------- |
| enable | number | 开关         | 1: 开, 0: 关     |

调用示例:

```typescript
// 设置
await RwBleSdk.setFallDetect(1)

// 获取
const res = await RwBleSdk.getFallDetect()
console.log(`跌落提醒: ${JSON.stringify(res)}`)
```



##### 3.2.1.25 计数提醒间隔设置

> 配置表属性: `isSupportCountReminder`

方法说明:

`RwBleSdk.setCountReminderInterval(minutes: number): Promise<void>`

`RwBleSdk.getCountReminderInterval(): Promise<Object>`

参数说明:

| 参数    | 类型   | 说明     | 值                                       |
| ------- | ------ | -------- | ---------------------------------------- |
| minutes | number | 间隔分钟 | 0: 关闭, 30/60/90/120: 提醒间隔(分钟) |

调用示例:

```typescript
// 设置60分钟提醒
await RwBleSdk.setCountReminderInterval(60)

// 获取
const mins = await RwBleSdk.getCountReminderInterval()
console.log(`计数提醒间隔: ${mins}分钟 (0=关闭)`)

// 关闭
await RwBleSdk.setCountReminderInterval(0)
```



#### 3.2.2 健康数据同步(实时单次与全天检测)

> 健康数据检测有两种方式: 实时单次检测与全天检测。健康数据包括心率,血氧,压力,HRV,睡眠等, **睡眠无实时检测**。 
>
> (1) 实时单次检测: APP侧启动设备进入单次检测,检测完后马上返回结果。
>
> (2) 全天检测: 可设置间隔时间,比如30分钟或60分钟设备会进行检测并保存值; **app一直不同步情况下,设备可保存3-6天的数据**。



##### 3.2.2.1 实时检测-启动与关闭设备健康数据检测

> 启动健康数据检测(心率,血氧,HRV,压力,血糖等).

> [!CAUTION]
>
> 同一时间只能开启一种健康检测类型, 必须等当前检测结束(收到完成回调)或主动关闭后, 才能启动新的检测类型.

方法说明:

`RwBleSdk.controlHealthData(healthType: number, start: number | boolean): Promise<void>`

`RwBleSdk.onHealthRealtimeData(cb: (data: HealthDataSyncBean) => void): () => void`

`RwBleSdk.onHealthControlEvent(cb: (value: Object) => void): () => void`

参数说明:

| 参数       | 类型       | 说明         | 值                                                           |
| ---------- | ---------- | ------------ | ------------------------------------------------------------ |
| healthType | number | 健康数据类型 | HealthType.HR / BO / HRV / PRESSURE / BLOOD_SUGAR / BP / TEMPERATURE |
| start      | number \| boolean | 启动/关闭 | true/1: 启动, false/0: 关闭 |

调用示例:

```typescript
import { HealthType } from 'rw_ble_sdk'

// 订阅实时健康数据
const unsub = RwBleSdk.onHealthRealtimeData((data) => {
  switch (data.dataType) {
    case HealthType.HR:
      console.log(`心率: ${data.hrValue}`)
      break
    case HealthType.BO:
      console.log(`血氧: ${data.boValue}`)
      break
    case HealthType.HRV:
      console.log(`HRV: ${data.hrvValue}`)
      break
    case HealthType.PRESSURE:
      console.log(`压力: ${data.pressureValue}`)
      break
    case HealthType.BLOOD_SUGAR:
      console.log(`血糖: ${data.bloodSugarValue}`)
      break
    case HealthType.BP:
      console.log(`血压: ${data.bpSp}/${data.bpDp}`)
      break
    case HealthType.TEMPERATURE:
      console.log(`体温: ${data.temperature}℃`)
      break
  }
})

const unsubControl = RwBleSdk.onHealthControlEvent((value) => {
  // 设备健康检测控制状态上报
  console.log(`健康检测状态: ${JSON.stringify(value)}`)
})

// 启动心率检测
await RwBleSdk.controlHealthData(HealthType.HR, true)

// 关闭心率检测
await RwBleSdk.controlHealthData(HealthType.HR, false)
unsub()
unsubControl()
```

HealthDataSyncBean 说明:

| 字段            | 类型   | 说明                                           |
| --------------- | ------ | ---------------------------------------------- |
| dataType        | number | 健康数据类型，对应 `HealthType`                |
| value           | number | 通用值，部分数据类型会同时填充具体字段         |
| value2          | number | 通用第二值，如血压舒张压等                     |
| timestamp       | number | 数据时间戳，秒(s)                              |
| date            | string | 日期，yyyy-MM-dd                               |
| hour            | string | 小时，HH                                       |
| hrValue         | number | 心率值                                         |
| boValue         | number | 血氧值                                         |
| hrvValue        | number | HRV值                                          |
| pressureValue   | number | 压力值                                         |
| bloodSugarValue | number | 血糖值                                         |
| bpSp            | number | 收缩压                                         |
| bpDp            | number | 舒张压                                         |
| tempValue       | number | 体温原始值                                     |
| temperature     | number | 体温实际值                                     |
| steps           | number | 实时活动步数                                   |
| calorie         | number | 实时活动卡路里                                 |
| distance        | number | 实时活动距离                                   |
| muslimCount     | number | 赞念实时计数                                   |



##### 3.2.2.2 全天检测-设置健康数据全天监听间隔

> 设置健康数据全天监听间隔，单位分钟.
>
> **注意:暂间隔只有心率可设置30分钟与60分钟, 其它(血氧,HRV,压力,血糖)只能设置开与关; 开始与结束时间固定全天,不可修改.**

###### 3.2.2.2.1 心率检测设置与获取

方法说明: 

`RwBleSdk.setTimedHeartRate(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedHeartRate(): Promise<Object>`

参数说明:

| 参数         | 类型              | 说明 | 值                                                           |
| ------------ | ----------------- | ---- | ------------------------------------------------------------ |
| reminderBean | DrinkReminderBean | 类   | isOpen: true开/false关<br>remindDuration: 间隔时间30或60分钟<br>startHour: 0 固定<br>startMin: 0 固定<br>endHour: 23 固定<br>endMin: 59 固定 |

调用示例:

```typescript
// 设置心率监听
await RwBleSdk.setTimedHeartRate({
  isOpen: true,
  remindDuration: 60,
  startHour: 0, startMin: 0, endHour: 23, endMin: 59
})

// 获取
const hr = await RwBleSdk.getTimedHeartRate()
console.log(`心率监听: ${hr.isOpen} 间隔${hr.remindDuration}分钟`)
```

###### 3.2.2.2.2 血氧检测设置与获取

> 配置表属性: `isBloodOxy`; 间隔固定60分钟.

`RwBleSdk.setTimedBloodOxygen(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedBloodOxygen(): Promise<Object>`

###### 3.2.2.2.3 心率变异性(HRV)检测设置与获取

> 配置表属性: `isHrv`; 间隔固定60分钟.

`RwBleSdk.setTimedHRV(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedHRV(): Promise<Object>`

###### 3.2.2.2.4 压力检测设置与获取

> 配置表属性: `isPressure`; 间隔固定60分钟.

`RwBleSdk.setTimedStress(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedStress(): Promise<Object>`

###### 3.2.2.2.5 血糖检测设置与获取

> 配置表属性: `isBloodSugar`; 间隔固定60分钟.

`RwBleSdk.setTimedBloodSugar(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedBloodSugar(): Promise<Object>`

###### 3.2.2.2.6 血压检测设置与获取

> 配置表属性: `isBloodPress`; 间隔固定60分钟.

`RwBleSdk.setTimedBloodPressure(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedBloodPressure(): Promise<Object>`

###### 3.2.2.2.7 体温检测设置与获取

> 配置表属性: `isSupportTemperatureMonitoring`; 间隔可设置30或60分钟.

`RwBleSdk.setTimedBodyTemperature(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedBodyTemperature(): Promise<Object>`

> 以上 3.2.2.2.2 ~ 3.2.2.2.7 用法与心率一致，仅方法名不同.



##### 3.2.2.3 全天检测-同步健康历史数据

> 同步所有健康历史数据, **会自动根据配置表依次获取支持类型的健康数据**.

方法说明:

`RwBleSdk.syncAllHealthData(cb: HealthSyncCallback): void`

`RwBleSdk.removeHealthDataCallback(cb: HealthSyncCallback): void`

调用示例:

```typescript
RwBleSdk.syncAllHealthData({
  onSyncProgress(progress: number) {
    console.log(`同步进度: ${progress}%`)
  },
  onSyncFinish() {
    console.log('同步完成')
  },
  onSyncError(code: number) {
    console.error(`同步错误: ${code}`)
  },
  onSyncStep(data: StepSyncBean[]) {
    data.forEach(d => console.log(`步数: ${d.totalSteps} 日期:${d.date}`))
  },
  onSyncSleep(data: SleepSyncBean[]) {
    data.forEach(d => console.log(`睡眠片段: ${d.timestamp} 模式:${d.sleepModel}`))
  },
  onSyncHr(data: HeartRateSyncBean[]) {
    console.log(`心率数据: ${data.length}天`)
  },
  onSyncBo(data: BloodOxySyncBean[]) {},
  onSyncBp(data: BloodPressSyncBean[]) {},
  onSyncTemp(data: BodyTempSyncBean[]) {},
  onSyncPressure(data: PressureSyncBean[]) {},
  onSyncBloodSugar(data: BloodSugarSyncBean[]) {},
  onSyncHrv(data: HrvSyncBean[]) {},
  onSyncMuslimCount(data: MuslimCountSyncBean[]) {}
})
```

###### 3.2.2.3.1 获取单个健康数据

方法说明:

`RwBleSdk.syncHealthDataByType(type: number, cb: HealthSyncCallback): void`

调用示例:

```typescript
import { RingHealthType } from 'rw_ble_sdk'

// 获取今天步数
RwBleSdk.syncHealthDataByType(RingHealthType.TODAY_STEP, syncCallback)
```



##### 3.2.2.4 全天检测-健康数据说明

1. 今天与历史计步数据 `onSyncStep(data: StepSyncBean[])`

   > [!CAUTION]
   > 如果有历史数据会分两次回调, 第一次为今天的数据; 第二次为历史计步数据.

   ```typescript
   interface StepSyncBean {
     timestamp: number       // 日期时间戳 秒(s)
     date: string            // 日期, yyyy-MM-dd
     hour: string            // 小时, HH
     totalSteps: number      // 总步数
     totalCalorie: number    // 总卡路里cal
     totalDistance: number   // 总里程m
     itemCount: number       // 数据量
     items: StepItemBean[]   // 每小时的计步数据
   }

   interface StepItemBean {
     index: number    // 小时序号(0-23)
     steps: number    // 步数
     calorie: number  // 卡路里
     distance: number // 里程
   }
   ```

2. 睡眠数据 `onSyncSleep(data: SleepSyncBean[])`

   ```typescript
   interface SleepSyncBean {
     timestamp: number   // 睡眠片段时间戳 秒(s)
     sleepModel: number  // 睡眠模式
     isTemporary: number // 是否临时睡眠数据
   }
   ```

3. 心率数据 `onSyncHr(data: HeartRateSyncBean[])`

   ```typescript
   interface HeartRateSyncBean {
     timestamp: number            // 日期时间戳 秒(s)
     date: string                 // 日期, yyyy-MM-dd
     itemCount: number            // 数据量
     items: HeartRateItemBean[]   // 对应天的心率值
   }

   interface HeartRateItemBean {
     timestamp: number  // 时间戳 秒(s)
     date: string       // 日期, yyyy-MM-dd
     hour: string       // 小时, HH
     hr: number         // 心率值
   }
   ```

   **HRV(`HrvSyncBean`), 血氧(`BloodOxySyncBean`), 压力(`PressureSyncBean`), 血糖(`BloodSugarSyncBean`), 血压(`BloodPressSyncBean`) 与心率类似不一一说明.**

4. 体温数据 `onSyncTemp(data: BodyTempSyncBean[])`

   ```typescript
   interface BodyTempSyncBean {
     timestamp: number          // 日期时间戳 秒(s)
     date: string               // 日期, yyyy-MM-dd
     itemCount: number          // 数据量
     items: BodyTempItemBean[]
   }

   interface BodyTempItemBean {
     timestamp: number   // 测量时间戳 秒(s)
     date: string        // 日期, yyyy-MM-dd
     hour: string        // 小时, HH
     temp: number        // 体温原始值(如365)
     temperature: number // 实际温度(如36.5℃)
   }
   ```

5. 赞念数据 `onSyncMuslimCount(data: MuslimCountSyncBean[])`

   ```typescript
   interface MuslimCountSyncBean {
     timestamp: number               // 日期时间戳 秒(s)
     date: string                    // 日期, yyyy-MM-dd
     itemCount: number               // 数据量
     totalCount: number              // 总数据量
     items: MuslimCountItemBean[]
   }

   interface MuslimCountItemBean {
     timestamp: number  // 时间戳 秒(s)
     date: string       // 日期, yyyy-MM-dd
     hour: string       // 小时, HH
     count: number      // 计数数量;每小时累加赞念
   }
   ```



#### 3.2.3 OTA升级

> [!NOTE]
>
> OTA升级文件需从厂家生成取得，确定无误后再进行测试. 防止升级出错变砖.
>
> 当前 HarmonyOS 版本保留 OTA 章节和 API 入口，`ringOtaWithFileData` 暂未实现文件升级流程，会通过 `onError(-3)` 返回不支持。后续实现后本章节保持与 Android OTA 章节对齐补充。

方法说明:

`RwBleSdk.ringOtaWithFileData(filePath: string, cb: OTACallback): void`

调用示例:

```typescript
RwBleSdk.ringOtaWithFileData(otaFilePath, {
  onProgress(pro: number) {
    console.log(`OTA进度: ${pro}%`)
  },
  onSuccess() {
    console.log('OTA升级完成')
  },
  onError(code: number) {
    console.error(`OTA失败: ${code}`)
  }
})
```



#### 3.2.4 多运动Workout

>  [!CAUTION]
>
> 支持多运动配置表属性为 `isNewSport`; 开启多运动后, 设备会进入运动中, APP断开与关闭都不会停止,只有通过APP或设备主动停止;
>
> **运动时长需超过2分钟,设备才会保存此次运动数据.**



##### 3.2.4.1 获取设备多运动状态

> 获取设备是否在多运动中; 当前不在运动中时才开启新的运动.

方法说明: 

`RwBleSdk.getSportStatus(): Promise<Object>`

NewSportBean 说明:

| 参数       | 类型              | 说明     |
| ---------- | ----------------- | -------- |
| sportType  | BleActivityMode   | 运动类型 |
| status     | WorkoutControlType | 运动状态 |

WorkoutControlType:

| 枚举值           | 说明     |
| ---------------- | -------- |
| Workout_Begin    | 运动开始 |
| Workout_Continue | 运动继续 |
| Workout_Pause    | 运动暂停 |
| Workout_Finish   | 运动结束 |

调用示例:

```typescript
import { WORKOUT_BEGIN, WORKOUT_CONTINUE } from 'rw_ble_sdk'

const sport = await RwBleSdk.getSportStatus()
if (sport.status === WORKOUT_BEGIN || sport.status === WORKOUT_CONTINUE) {
  console.log('设备正在运动中')
}
```



##### 3.2.4.2 控制设备进入多运动

方法说明: 

`RwBleSdk.controlSport(sportType: BleActivityMode, status: WorkoutControlType): Promise<void>`

`RwBleSdk.onSportDataPush(cb: (value: Object) => void): () => void`

`RwBleSdk.onSportControl(cb: (value: Object) => void): () => void`

SportDataPushBean 说明:

| 参数             | 类型   | 说明                          |
| ---------------- | ------ | ----------------------------- |
| activityTime     | number | 运动持续时间,单位 秒(s)       |
| activitySteps    | number | 运动中步数                    |
| activityDistance  | number | 运动中产生距离, 单位 米(m)    |
| activityCalorie  | number | 运动中产生热量, 单位 卡(cal)  |
| activityHr       | number | 运动中动态心率                |

调用示例:

```typescript
import { BLE_ACTIVITY_RUNNING, WORKOUT_BEGIN, WORKOUT_PAUSE, WORKOUT_FINISH } from 'rw_ble_sdk'

// 订阅运动数据推送
const unsub = RwBleSdk.onSportDataPush((data) => {
  const sportData = data as SportDataPushBean
  console.log(`时间:${sportData.activityTime}s 步数:${sportData.activitySteps} 心率:${sportData.activityHr}`)
})

const unsubControl = RwBleSdk.onSportControl((value) => {
  console.log(`运动控制状态: ${JSON.stringify(value)}`)
})

// 开始运动
await RwBleSdk.controlSport(BLE_ACTIVITY_RUNNING, WORKOUT_BEGIN)

// 暂停运动
await RwBleSdk.controlSport(BLE_ACTIVITY_RUNNING, WORKOUT_PAUSE)

// 结束运动
await RwBleSdk.controlSport(BLE_ACTIVITY_RUNNING, WORKOUT_FINISH)
unsub()
unsubControl()
```



##### 3.2.4.3 控制开启/关闭设备实时通知运动数据

方法说明: 

`RwBleSdk.setExerciseNotify(enable: number | boolean): Promise<void>`

调用示例:

```typescript
// 退出运动界面,关闭通知
await RwBleSdk.setExerciseNotify(false)
```



##### 3.2.4.4 获取多运动数据报告

方法说明: 

`RwBleSdk.getSportResult(): Promise<Object>`

SportResultBean 参数说明:

| 参数          | 类型              | 说明                           |
| ------------- | ----------------- | ------------------------------ |
| startTime     | number            | 运动开始时间戳, 单位秒(s)      |
| exerciseTime  | number            | 运动时长,单位秒(s)             |
| workModel     | BleActivityMode   | 运动类型                       |
| step          | number            | 步数                           |
| distance      | number            | 距离,米(m)                     |
| calorie       | number            | 卡路里, 卡(cal)                |
| newSportHrs   | number[]          | 运动心率列表, 1分钟保存一个    |
| pacePerKmList | number[]          | 每公里配速列表, 单位秒/公里    |

调用示例:

```typescript
const results = await RwBleSdk.getSportResult()
;(results as SportResultBean[]).forEach(r => {
  console.log(`运动: ${r.workModel} 时长:${r.exerciseTime}s 步数:${r.step}`)
})
```



#### 3.2.5 传感器原始数据

> PPG/ACC/PPG Red/IR传感器原始数据采集与睡眠实时数据;
>
> 配置表属性: `isSupportSensorRawPPG` (PPG), `isSupportSensorRawACC` (ACC), `isSupportSensorRawPPGRed` (PPG Red), `isSupportSensorRawIR` (IR), `isSupportSensorRawSleep` (睡眠实时数据);
>
> **注意: 睡眠实时数据(sensorType=5)无需手动启动与关闭, 设备支持时会在睡眠过程中自动推送.**

sensorType 合法组合:

| 值   | 含义              | 说明                    |
| ---- | ----------------- | ----------------------- |
| 1    | ACC               | 仅ACC                   |
| 2    | 绿光(PPG Green)   | 仅绿光                  |
| 3    | 绿光 + ACC        | 绿光与ACC同时输出       |
| 4    | 红光(PPG Red)     | 仅红光                  |
| 5    | 红光 + ACC        | 红光与ACC同时输出       |
| 10   | 绿光 + 红外(IR)   | 绿光与红外同时输出      |
| 11   | 绿光 + ACC + 红外 | 绿光、ACC与红外同时输出 |
| 12   | 红光 + 红外       | 红光与红外同时输出      |
| 13   | 红光 + ACC + 红外 | 红光、ACC与红外同时输出 |

> **规则: 绿光与红光不能共存; 红外不能单独启动,必须与绿光或红光组合使用.**

##### 3.2.5.0 PPG定时监测

> 配置表属性: `isSupportPPGMonitoring`

`RwBleSdk.setTimedPPG(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedPPG(): Promise<Object>`

> 用法同心率定时监测(3.2.2.2.1)一致.

##### 3.2.5.1 启动与关闭传感器原始数据

方法说明: 

`RwBleSdk.controlSensorRaw(outputType: number, sensorType: number): Promise<void>`

`RwBleSdk.onSensorRawData(cb: (value: Object) => void): () => void`

参数说明:

| 参数       | 类型   | 说明         | 值                                     |
| ---------- | ------ | ------------ | -------------------------------------- |
| outputType | number | 输出控制类型 | 1: 开启Sensor输出<br>2: 关闭Sensor输出 |
| sensorType | number | 传感器类型   | 见上方合法组合表                       |

返回数据 SensorRawDataBean 格式说明:

| 字段           | 类型              | 说明                                    |
| -------------- | ----------------- | --------------------------------------- |
| type           | number            | 1=PPG, 2=ACC, 3=PPG Red, 4=IR, 5=睡眠  |
| ppgDataList    | number[]          | PPG数据列表                             |
| accDataList    | AccRawItem[]      | ACC数据列表, 每项含x,y,z               |
| ppgRedDataList | number[]          | PPG Red数据列表                         |
| irDataList     | number[]          | IR红外数据列表                          |
| sleepDataList  | SleepRawItem[]    | 睡眠数据: time(时间戳), mode(睡眠模式)  |

调用示例:

```typescript
// 订阅传感器数据
const unsub = RwBleSdk.onSensorRawData((data) => {
  const sensorData = data as SensorRawDataBean
  switch (sensorData.type) {
    case 1: console.log(`PPG: ${sensorData.ppgDataList?.length ?? 0}项`); break
    case 2: console.log(`ACC: ${sensorData.accDataList?.length ?? 0}项`); break
    case 3: console.log(`PPG Red: ${sensorData.ppgRedDataList?.length ?? 0}项`); break
    case 4: console.log(`IR: ${sensorData.irDataList?.length ?? 0}项`); break
    case 5: console.log(`Sleep: ${sensorData.sleepDataList?.length ?? 0}项`); break
  }
})

// 开启PPG+ACC
await RwBleSdk.controlSensorRaw(1, 3)

// 关闭
await RwBleSdk.controlSensorRaw(2, 3)
unsub()
```


##### 3.2.5.2 历史传感器数据获取

> 获取设备保存的传感器历史原始数据.

方法说明:

`RwBleSdk.getSensorHistoryRaw(): Promise<Object>`

调用示例:

```typescript
try {
  const history = await RwBleSdk.getSensorHistoryRaw()
  console.log(`传感器历史: ${JSON.stringify(history)}`)
} catch (e) {
  console.error('获取传感器历史失败', e.message)
}
```



## SDK修订记录

**v1.0.0_20260701** (2026.07.01)
- HarmonyOS SDK 首版发布
- 基于 Android SDKV2.0 移植
- API 采用 Promise + 订阅混合模式


## 联系方式 / 技术支持

- 技术支持邮箱  developer@dhouse88.com
