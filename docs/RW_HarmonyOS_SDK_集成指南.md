# RW HarmonyOS SDK 集成指南

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

1. 使用此SDK时建议结合示例工程 `rw_ble_sdk_demo`，具体用法可参考示例工程。

2. `RwBleSdk` 指令操作分两种模式:
   - **一问一答型**（GET/SET类）: 直接使用 `await` 获取结果，无需手动订阅和取消;
   - **持续推送型**（实时数据/同步流）: 使用回调订阅，返回取消函数，不再使用时调用取消即可;



## 2. 快速开始（Quick Start）

**第1步: 获取最新版本的DevEco Studio**

要想使用 RW BLE SDK for HarmonyOS 开发项目，您需要安装 DevEco Studio.

**第2步: 添加依赖库**

1. 将 `rw_ble_sdk.har` 复制到应用模块的 `libs` 目录。

2. 在应用模块的 `oh-package.json5` 中添加 HAR 依赖:

```json
{
  "dependencies": {
    "rw_ble_sdk": "file:./libs/rw_ble_sdk.har"
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
    "usedScene": {
      "abilities": ["EntryAbility"],
      "when": "always"
    }
  }
]
```

`ACCESS_BLUETOOTH` 是 `user_grant` 权限，除了声明权限，还需要在运行时请求用户授权:

```typescript
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'

const context = this.getUIContext().getHostContext() as common.Context
const permissions: Array<Permissions> = ['ohos.permission.ACCESS_BLUETOOTH']
const atManager = abilityAccessCtrl.createAtManager()
await atManager.requestPermissionsFromUser(context, permissions)
```

> HarmonyOS 需要申请 `ACCESS_BLUETOOTH` 权限。

**第4步: 初始化SDK**

```typescript
import { common } from '@kit.AbilityKit'
import { RwBleSdk } from 'rw_ble_sdk'

const context = this.getUIContext().getHostContext() as common.Context
RwBleSdk.initSDK(context)
```

SDK 应在扫描或连接前初始化，应用进程内初始化一次即可。

> [!CAUTION]
>
> 会默认保存蓝牙部分日志文件, 保存在应用沙箱 `files/logger/devices/` 文件夹下. 可 `RwBleSdk.setLogEnable(false)` 关闭. 导出或分享日志前建议调用 `RwBleSdk.flushLog()`.



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

SDK 默认只返回支持的 RW 设备，扫描会在 15 秒后自动停止。

`RwBleDevice` 中与连接相关的主要字段:

| 字段 | 说明 |
| --- | --- |
| `deviceId` | HarmonyOS 当前扫描得到的设备标识，连接时必须使用；设备重启或 OTA 后可能变化 |
| `mac` | 设备真实 MAC，建议用于持久化识别设备 |
| `name` | 设备广播名称 |
| `rssi` | 当前扫描信号强度 |
| `data` | 原始广播数据 |

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
##### 3.1.4 断开连接设备

> 接口说明: 断开正在连接的设备

```typescript
RwBleSdk.disconnect()
```

当前连接状态可通过 `RwBleSdk.isBleConnected(): boolean` 获取。

##### 3.1.5 本地绑定与自动重连,解绑

> [!IMPORTANT]
>
> HarmonyOS本地绑定,自动重连需自行实现, 本SDK不提供此功能;可以连接成功后,保存设备真实 `mac` 与配置表,方便页面显示与重连.

HarmonyOS 扫描上报的 `deviceId` 可能是系统分配的当前设备标识，并不一定是设备真实 MAC。设备重启或 OTA 后，不建议直接使用持久化的旧 `deviceId`。推荐的重连流程为:

1. 扫描附近设备；
2. 用已保存的真实 `mac` 匹配扫描结果；
3. 找到后立即调用 `RwBleSdk.stopScan()`；
4. 保存最新扫描结果，再使用最新 `deviceId` 连接。

```typescript
let matched = false

RwBleSdk.startScan({
  onScanDevice(device: RwBleDevice) {
    if (matched || normalize(device.mac) !== normalize(savedDevice.mac)) return
    matched = true

    // 连接前先停止扫描
    RwBleSdk.stopScan()

    // 业务层应在此保存 device，用最新 deviceId 覆盖旧记录
    saveDevice(device)
    RwBleSdk.reconnectDevice(device)
  },
  onScanFinish() {
    if (!matched) console.info('未发现已绑定设备')
  },
  onError(code: number, error: Error) {
    console.error(`重连扫描失败: ${code} ${JSON.stringify(error)}`)
  }
})

function normalize(value?: string): string {
  return (value ?? '').replace(/[:-]/g, '').toUpperCase()
}
```

`RwBleSdk.reconnectDevice(device: RwBleDevice): void` 仅使用传入的设备信息发起连接，不会自动扫描。



##### 3.1.6 设备功能配置表

>  [!IMPORTANT]
>
> 因设备型号多, 支持的功能不同,所以引入功能表信息,可查询设备功能支持情况. 具体参考 SupportMenuBean 类. 可根据业务自行保存功能表内容. 

`onRingDidFunctionMenu(menu: SupportMenuBean)`

已连接后也可通过 `RwBleSdk.getSupportMenu(): SupportMenuBean | null` 获取当前缓存的配置表。

SupportMenuBean 属性定义:

| SupportMenuBean属性         | 说明                     |
| --------------------------- | ------------------------ |
| name/mac/uuid               | 当前设备名称、真实MAC与连接标识 |
| isPushMsgEnableSwitch       | 是否启用消息控制开关     |
| isAlarm                     | 是否支持闹钟             |
| isBrightScreenSleepTime     | 是否支持屏幕睡眠时间设置 |
| isBrightScreenTime          | 是否支持亮屏时长         |
| isRaiseBrightScreen         | 是否支持抬腕亮屏         |
| isLEDLight                  | 是否支持LED亮度设置      |
| isWearDir                   | 是否支持佩戴方向设置     |
| isTakePhoto                 | 是否支持拍照控制         |
| isNewSport                  | 是否支持多运动           |
| isRememberSwitch            | 是否支持Muslim赞念开关   |
| isSupportHrReminder         | 是否支持HR报警提示功能   |
| isSupportBoReminder         | 是否支持SP02报警提示功能 |
| isSupportMotoVibrationLevel | 是否支持马达震动提醒     |
| isSupportAlarmVibrationDuration | 是否支持闹钟震动时长设置 |
| isSupportVibrationInterval  | 是否支持震动间隔时长设置 |
| isStep                      | 是否支持计步             |
| activityDataInterval        | 当天计步明细间隔（分钟）；未配置时按60处理 |
| isActivityDataStaticTran2   | 是否支持实时活动数据上报 |
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
| isSupportDevicePasswordAuth | 是否支持设备密码认证       |
| isSupportScreenControl      | 是否支持即时屏幕亮灭控制   |



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
| person | PersonBean | 类   | gender: 性别（0.女 1.男)<br>height: 身高cm,浮点型<br>weight: 体重kg,浮点型<br>age: 年龄<br>measureUnit: 单位制（0.公制 1.英制） |

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
  console.error('用户信息设置失败', JSON.stringify(e))
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
  console.log(`设备型号: ${info.deviceClazz ?? '-'}`)
  console.log(`固件版本: ${info.deviceNo}`)
  console.log(`UI版本: ${info.uiVersion ?? '-'}`)
  console.log(`屏幕: ${info.screenWidth ?? '-'}x${info.screenHeight ?? '-'}`)

  const mac = await RwBleSdk.getMacAddress()
  console.log(`设备MAC: ${mac}`)
} catch (e) {
  console.error('获取设备信息失败', JSON.stringify(e))
}
```

FirmVersionBean:

```typescript
interface FirmVersionBean {
  deviceNo: string      // 设备版本号
  deviceClazz?: string  // 设备型号
  screenType?: number   // 0方 1圆
  screenWidth?: number  // 设备宽
  screenHeight?: number // 设备高
  uiVersion?: string    // UI版本号
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
  console.error('获取电量失败', JSON.stringify(e))
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

`RwBleSdk.getVideoHid(): Promise<VideoHidBean>`

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

`RwBleSdk.getRingLedLevel(): Promise<BrightScreenLedBean>`

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

`RwBleSdk.getRingWearDir(): Promise<number>`

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

`RwBleSdk.onTakePhotoEvent(cb: (value: number) => void): () => void`

调用示例:

```typescript
// 订阅设备拍照事件
const unsub = RwBleSdk.onTakePhotoEvent((value) => {
  // value 为设备主动上报的拍照事件值
  console.log(`拍照事件: ${value}`)
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

`RwBleSdk.getAlarmRemind(): Promise<AlarmRemainderBean[]>`

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

`setAlarm()` 与 `setAlarmRemind()` 功能相同，任选其一使用。

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

`RwBleSdk.getVibrationCount(): Promise<VibrationCountBean>`

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

`RwBleSdk.getRingBrightScreenSleepTime(): Promise<BrightScreenTimeBean>`

参数说明:

| BrightScreenTimeBean参数 | 类型    | 说明                     |
| ------------------------ | ------- | ------------------------ |
| timeSecond               | number  | 亮屏时长（秒） |
| isOpen                   | boolean | 开关打开或关闭           |
| startHour                | number  | 开始时间小时             |
| startMin                 | number  | 开始时间分钟             |
| endHour                  | number  | 结束时间小时             |
| endMin                   | number  | 结束时间分钟             |

调用示例:

```typescript
// 设置
await RwBleSdk.setRingBrightScreenSleepTime({
  timeSecond: 10,
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

`appId` 和标题最多分别发送32字节，正文最多发送250字节；超出部分由SDK按UTF-8字节截断。

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

`RwBleSdk.onMusicControl(cb: (value: number) => void): () => void`

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

`RwBleSdk.getMuslimCountSwitch(): Promise<number>`

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

`RwBleSdk.getHrAlert(): Promise<HrAlertBean>`

`RwBleSdk.setHrAlert(status: number, value: number, underValue: number): Promise<void>`

`RwBleSdk.getBoAlert(): Promise<BoAlertBean>`

`RwBleSdk.setBoAlert(status: number, value: number): Promise<void>`

`RwBleSdk.onHrBoAlertEvent(cb: (value: HrBoActualReminderBean) => void): () => void`

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

`RwBleSdk.getBrightScreenTime(): Promise<BrightScreenTimeBean>`

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



##### 3.2.1.18 获取与设置抬腕亮屏时长

>  配置表属性: `isRaiseBrightScreen`

方法说明: 

`RwBleSdk.getRaiseBrightScreen(): Promise<BrightScreenBean>`

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

`RwBleSdk.getAlarmVibrationDuration(): Promise<number>`

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

`RwBleSdk.onTouchEvent(cb: (value: TouchEventBean) => void): () => void`

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

`RwBleSdk.getVibrationInterval(): Promise<number>`

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

`RwBleSdk.onFactoryTest(cb: (value: FactoryTestResult) => void): () => void`

调用示例:

```typescript
// 如需观察“校正中(result=0)”和最终结果，先订阅状态
const unsub = RwBleSdk.onFactoryTest((status) => {
  console.log(`校正状态: mode=${status.testMode} result=${status.result}`)
})

// Promise会忽略中间的result=0，在非0最终结果到达后完成
const result = await RwBleSdk.startFactoryTest(0x15)
console.log(`心率校正结果: ${result}`)
unsub()
```



##### 3.2.1.24 跌落提醒设置

> 配置表属性: `isSupportFallDetect`
>
> 开启后设备检测到跌落时会通过触摸事件通知(3.2.1.21)上报, keyType=2.

方法说明:

`RwBleSdk.setFallDetect(enable: number): Promise<void>`

`RwBleSdk.getFallDetect(): Promise<number>`

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

`RwBleSdk.getCountReminderInterval(): Promise<number>`

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


##### 3.2.1.26 设备密码认证

> 配置表属性: `isSupportDevicePasswordAuth`

支持该功能的设备会在初始化期间自动认证密码，认证成功后才回调
`onRingDidFunctionMenu`；认证失败时 SDK 主动断开，并通过
`onRingConnectFailed("PASSWORD_AUTH_FAILED")` 返回。不支持该功能的设备保持原连接流程。

连接前设置自动认证密码，密码固定为4位数字；空值按默认密码 `0000` 处理：

```typescript
RwBleSdk.prepareAutoPassword('1234')
RwBleSdk.connectDeviceWithModel(bleDevice)
```

修改设备密码：

```typescript
try {
  await RwBleSdk.modifyDevicePwd('5678')
  console.log('密码修改成功')
} catch (e) {
  console.error('密码修改失败', JSON.stringify(e))
}
```

正常解绑支持密码认证的设备时，业务端应在设备保持连接的情况下先调用
`await RwBleSdk.modifyDevicePwd('0000')`，成功后再断开连接并清除本地绑定信息。

###### 3.2.1.26.3 准备授权密码重置

方法说明:

`RwBleSdk.preparePasswordReset(targetPassword?: string | null): void`

> 当无法获得设备原密码时，业务端可在确认用户具备设备重置权限后调用本方法，为下一次连接设置新的目标密码，避免已设置密码的设备无法继续使用。重置权限的确认方式由业务端决定，扫描包装盒二维码只是其中一种方式。

参数说明:

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| targetPassword | string \| null | 重置后的4位数字密码；传入 `null` 或空字符串时按 `0000` 处理 |

调用示例:

```typescript
// 业务端确认用户具备重置权限后调用。
RwBleSdk.preparePasswordReset('1234')
RwBleSdk.connectDeviceWithModel(bleDevice)
```

重置成功后，该密码会自动用于后续正常连接认证。该授权只对下一次连接有效。

##### 3.2.1.27 即时屏幕控制

> 配置表属性: `isSupportScreenControl`

方法说明:

`RwBleSdk.setScreenOn(isOn: boolean): Promise<void>`

参数说明:

| 参数 | 类型 | 说明 |
| --- | --- | --- |
| isOn | boolean | `true`: 亮屏；`false`: 息屏 |

调用示例:

```typescript
await RwBleSdk.setScreenOn(true)
await RwBleSdk.setScreenOn(false)
```



#### 3.2.2 健康数据同步(实时单次与全天检测)

> 健康数据检测有两种方式: 实时单次检测与全天检测。健康数据包括心率,血氧,压力,HRV,睡眠等, **睡眠不支持由 APP 主动启动单次检测**。部分设备可在睡眠过程中自动推送传感器原始睡眠数据。
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

`RwBleSdk.onHealthControlEvent(cb: (value: HealthControlEventBean) => void): () => void`

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
| value           | number（可选） | 通用值，部分数据类型会同时填充具体字段         |
| value2          | number（可选） | 通用第二值，如血压舒张压等                     |
| timestamp       | number（可选） | 数据时间戳，秒(s)                              |
| date            | string（可选） | 日期，yyyy-MM-dd                               |
| hour            | string（可选） | 小时，HH                                       |
| hrValue         | number（可选） | 心率值                                         |
| boValue         | number（可选） | 血氧值                                         |
| hrvValue        | number（可选） | HRV值                                          |
| pressureValue   | number（可选） | 压力值                                         |
| bloodSugarValue | number（可选） | 血糖值                                         |
| bpSp            | number（可选） | 收缩压                                         |
| bpDp            | number（可选） | 舒张压                                         |
| tempValue       | number（可选） | 体温原始值                                     |
| temperature     | number（可选） | 体温实际值                                     |
| steps           | number（可选） | 实时活动步数                                   |
| calorie         | number（可选） | 实时活动卡路里                                 |
| distance        | number（可选） | 实时活动距离                                   |
| muslimCount     | number（可选） | 赞念实时计数                                   |
| hrPartData      | HrPartData[]（可选） | 本次通知中的全部心率/HRV记录             |
| boPartData      | BoPartData[]（可选） | 本次通知中的全部血氧记录                  |
| bpPartData      | BpPartData[]（可选） | 本次通知中的全部血压记录                  |
| tempPartData    | TempPartData[]（可选） | 本次通知中的全部体温/血糖记录            |
| pressurePartData | PressurePartData[]（可选） | 本次通知中的全部压力记录             |
| stepJLPartData  | HistoryStepSyncBean[]（可选） | 本次通知中的全部实时活动记录       |
| muslimCountPartData | MuslimCountItemBean（可选） | 本次通知中的赞念记录 |

单值字段（如 `hrValue`、`timestamp`）保存本次通知最后一条记录；批量记录请优先读取对应的 `*PartData` 数组。



##### 3.2.2.2 全天检测-设置健康数据全天监听间隔

> 设置健康数据全天监听间隔，单位分钟.
>
> **注意:暂间隔只有心率可设置30分钟与60分钟, 其它(血氧,HRV,压力,血糖)只能设置开与关; 开始与结束时间固定全天,不可修改.**

###### 3.2.2.2.1 心率检测设置与获取

方法说明: 

`RwBleSdk.setTimedHeartRate(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedHeartRate(): Promise<DrinkReminderBean>`

参数说明:

| 参数         | 类型              | 说明 | 值                                                           |
| ------------ | ----------------- | ---- | ------------------------------------------------------------ |
| reminderBean | DrinkReminderBean | 类   | isOpen: true开/false关<br>remindDuration: 间隔时间30或60分钟<br>startHour: 固定为0<br>startMin: 固定为0<br>endHour: 固定为23<br>endMin: 固定为59 |

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

`RwBleSdk.getTimedBloodOxygen(): Promise<DrinkReminderBean>`

###### 3.2.2.2.3 心率变异性(HRV)检测设置与获取

> 配置表属性: `isHrv`; 间隔固定60分钟.

`RwBleSdk.setTimedHRV(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedHRV(): Promise<DrinkReminderBean>`

###### 3.2.2.2.4 压力检测设置与获取

> 配置表属性: `isPressure`; 间隔固定60分钟.

`RwBleSdk.setTimedStress(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedStress(): Promise<DrinkReminderBean>`

###### 3.2.2.2.5 血糖检测设置与获取

> 配置表属性: `isBloodSugar`; 间隔固定60分钟.

`RwBleSdk.setTimedBloodSugar(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedBloodSugar(): Promise<DrinkReminderBean>`

###### 3.2.2.2.6 血压检测设置与获取

> 配置表属性: `isBloodPress`; 间隔固定60分钟.

`RwBleSdk.setTimedBloodPressure(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedBloodPressure(): Promise<DrinkReminderBean>`

###### 3.2.2.2.7 体温检测设置与获取

> 配置表属性: `isSupportTemperatureMonitoring`; 间隔可设置30或60分钟.

`RwBleSdk.setTimedBodyTemperature(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedBodyTemperature(): Promise<DrinkReminderBean>`

> 以上 3.2.2.2.2 ~ 3.2.2.2.7 用法与心率一致，仅方法名不同.



##### 3.2.2.3 全天检测-同步健康历史数据

> 同步所有健康历史数据, **会自动根据配置表依次获取支持类型的健康数据**.

方法说明:

`RwBleSdk.syncAllHealthData(cb: HealthSyncCallback): void`

`RwBleSdk.removeHealthDataCallback(cb: HealthSyncCallback): void`

调用示例:

```typescript
const syncCallback: HealthSyncCallback = {
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
    data.forEach(d => console.log(`睡眠: ${d.totalSleepTime}分钟 片段:${d.itemCount}`))
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
}

RwBleSdk.syncAllHealthData(syncCallback)

// 页面退出或不再需要回调时再调用:
// RwBleSdk.removeHealthDataCallback(syncCallback)
```

###### 3.2.2.3.1 获取单个健康数据

方法说明:

`RwBleSdk.syncHealthDataByType(type: number, cb: HealthSyncCallback): void`

调用示例:

```typescript
import { RingHealthType } from 'rw_ble_sdk'

// 获取今天步数
RwBleSdk.syncHealthDataByType(RingHealthType.TODAY_STEP, syncCallback)

// 获取历史步数
RwBleSdk.syncHealthDataByType(RingHealthType.STEP, syncCallback)
```

同步错误码: `-1`已有同步进行中，`-2`尚未取得功能表，`-3`类型不受支持，`-4`命令超时/写失败，`-5`同步期间连接断开。



##### 3.2.2.4 全天检测-健康数据说明

1. 今天与历史计步数据 `onSyncStep(data: StepSyncBean[])`

   > [!CAUTION]
   > 如果有历史数据会分两次回调, 第一次为今天的数据; 第二次为历史计步数据.

   ```typescript
   interface StepSyncBean {
     timestamp: number       // 日期时间戳 秒(s)
     date: string            // 日期, yyyy-MM-dd
     hour: string            // 小时, HH
     activityDataInterval: number // 今天使用设备配置，历史固定60分钟
     totalSteps: number      // 总步数
     totalCalorie: number    // 总卡路里cal
     totalDistance: number   // 总里程m
     itemCount: number       // 数据量
     items: StepHourItem[]   // 设备返回的计步明细
   }

   interface StepHourItem {
     index: number     // 当前粒度下，当天第几个明细点
     timestamp: number // 明细准确时间戳 秒(s)
     steps: number     // 步数
     calorie: number   // 卡路里
     distance: number  // 里程
   }
   ```

   `activityDataInterval` 表示 `items` 的计步明细间隔，单位为分钟；
   `60` 表示每小时一条，`10` 表示每10分钟一条，未配置时默认为 `60`。
   请使用 `timestamp` 作为明细的准确时间。

2. 睡眠数据 `onSyncSleep(data: SleepSyncBean[])`

   ```typescript
   interface SleepSyncBean {
     timestamp: number      // 本次睡眠结束时间戳 秒(s)
     time: number           // 与timestamp一致
     totalSleepTime: number // 总时长 分钟
     asleepTime: number     // 入睡时间戳 秒(s)
     awakeTime: number      // 醒来时间戳 秒(s)
     itemCount: number
     items: SleepItemBean[]
   }

   interface SleepItemBean {
     len: number          // 当前阶段时长 分钟
     sleepType: number    // 0清醒、1浅睡、2深睡、3快速眼动
     isTemporary?: number
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

> [!CAUTION]
>
> OTA升级文件必须由设备厂家提供。升级前先通过 [3.2.1.3 获取设备信息](#3213-获取设备信息) 读取 `FirmVersionBean.deviceClazz`，并与升级文件适用的设备型号进行对比。只有两个型号完全一致时才能升级；型号不一致时禁止升级。
>
> SDK会自动识别 PXI 或 Telink OTA 平台，调用方无需选择平台。PXI 与 Telink 固件不可交叉使用，升级过程中请避免同时下发其他业务指令。

##### 3.2.3.1 获取可用固件

可通过以下接口查询指定设备型号的可用固件列表:

```http
GET https://ruiwo168.com/api/device/getOtaListByModel?model=<deviceClazz>
```

查询参数 `model` 对应 `getFirmwareVersion()` 返回的 `FirmVersionBean.deviceClazz`。请求接口前应先读取设备固件信息，并使用设备实际返回的 `deviceClazz` 作为 `model`。

```typescript
const firmware = await RwBleSdk.getFirmwareVersion()
const deviceClazz = firmware.deviceClazz
const currentVersion = firmware.deviceNo
const url = `https://ruiwo168.com/api/device/getOtaListByModel?model=${encodeURIComponent(deviceClazz)}`
console.log(`query firmware: ${url}, currentVersion=${currentVersion}`)
```

接口返回示例:

```json
{
  "code": 0,
  "msg": "操作成功",
  "data": [
    {
      "deviceModel": "DEVICE_MODEL",
      "toVersion": "X.Y.Z",
      "size": 123456,
      "downloadUrl": "https://example.com/path/firmware.bin"
    }
  ]
}
```

OTA流程只需关注 `data` 中的以下字段，其他字段可以忽略:

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| deviceModel | string | 固件适用的设备型号，应与 `FirmVersionBean.deviceClazz` 完全一致 |
| toVersion | string | 固件版本号，正式发布时用于判断是否有更高版本可升级 |
| size | number | 固件文件大小，单位为字节(Byte) |
| downloadUrl | string | 固件文件下载地址 |

正式发布时，APP应按 `X.Y.Z` 各段数值比较当前版本 `deviceNo` 与目标版本 `toVersion`，通常只提示升级到更高版本，不能直接按字符串比较。测试时可在确认固件有效后进行同版本升级或降级测试。

下载及升级前均须确认 `deviceModel` 与设备的 `deviceClazz` 完全一致。固件下载到本地后，将文件路径传给 `ringOtaWithFileData()`；如使用自有服务器，请自行维护设备型号、版本号与固件包的对应关系。

##### 3.2.3.2 执行OTA升级

方法说明:

`RwBleSdk.ringOtaWithFileData(filePath: string, cb: OTACallback): void`

调用示例:

```typescript
RwBleSdk.ringOtaWithFileData(otaFilePath, {
  onProgress(pro: number) {
    console.log(`OTA进度: ${Math.floor(pro * 100)}%`)
  },
  onSuccess() {
    console.log('OTA升级完成')
  },
  onError(code: number) {
    console.error(`OTA失败: ${code}`)
  }
})
```

`onProgress` 取值范围为 `0.0~1.0`。

错误码说明:

| 平台 | 错误码 | 含义 |
| --- | ---: | --- |
| 通用 | -3 | 当前连接未发现 PXI 或 Telink OTA 服务 |
| Telink | 1 | Telink升级过程中设备断开 |
| Telink | 2 | 固件文件读取失败 |
| Telink | 3 | OTA升级超时 |
| Telink | 4 | 设备返回升级失败 |
| Telink | 5 | OTA数据写入失败 |
| PXI | 11 | 固件文件读取失败 |
| PXI | 12 | 设备未连接或升级中断开 |
| PXI | 13 | CRC校验失败 |
| PXI | 14 | OTA步骤超时 |
| PXI | 15 | OTA数据写入失败或参数异常 |

> 请在设备连接成功并获取功能配置表后再启动 OTA。



#### 3.2.4 多运动Workout

>  [!CAUTION]
>
> 支持多运动配置表属性为 `isNewSport`; 开启多运动后, 设备会进入运动中, APP断开与关闭都不会停止,只有通过APP或设备主动停止;
>
> **运动时长需超过2分钟,设备才会保存此次运动数据.**



##### 3.2.4.1 获取设备多运动状态

> 获取设备是否在多运动中; 当前不在运动中时才开启新的运动.

方法说明: 

`RwBleSdk.getSportStatus(): Promise<NewSportBean>`

NewSportBean 说明:

| 参数       | 类型              | 说明     |
| ---------- | ----------------- | -------- |
| sportType  | number | 运动类型，使用 `BLE_ACTIVITY_*` 常量 |
| status     | number | 运动状态，使用 `WORKOUT_*` 常量 |

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

`RwBleSdk.controlSport(sportType: number, status: number): Promise<void>`

`RwBleSdk.onSportDataPush(cb: (value: SportDataPushBean) => void): () => void`

`RwBleSdk.onSportControl(cb: (value: NewSportBean) => void): () => void`

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

`RwBleSdk.getSportResult(): Promise<SportResultBean[]>`

SportResultBean 参数说明:

| 参数          | 类型              | 说明                           |
| ------------- | ----------------- | ------------------------------ |
| startTime     | number            | 运动开始时间戳, 单位秒(s)      |
| endTime       | number（可选）     | 运动结束时间戳, 单位秒(s)      |
| exerciseTime  | number            | 运动时长,单位秒(s)             |
| height        | number（可选）     | 海拔高度                       |
| barometricPressure | number（可选） | 气压                           |
| cadence       | number（可选）     | 步频,步/分钟                   |
| workModel     | number            | 运动类型，对应 `BLE_ACTIVITY_*` 常量 |
| step          | number            | 步数                           |
| distance      | number            | 距离,米(m)                     |
| calorie       | number            | 卡路里, 卡(cal)                |
| speed         | number（可选）     | 速度,米/小时                   |
| pace          | number（可选）     | 配速,秒/公里                   |
| averageHr/maxHr/minHr | number（可选） | 平均/最大/最小心率          |
| viewType      | number（可选）     | 运动数据显示类型               |
| maxCadence/minCadence | number（可选） | 最大/最小步频                    |
| maxPace/minPace | number（可选）   | 最大/最小配速                    |
| hrCount       | number（可选）     | 心率数据数量                   |
| newSportHrs   | number[]          | 运动心率列表, 1分钟保存一个    |
| pacePerKmList | number[]（可选）   | 每公里配速列表, 单位秒/公里    |

调用示例:

```typescript
const results = await RwBleSdk.getSportResult()
results.forEach(r => {
  console.log(`运动: ${r.workModel} 时长:${r.exerciseTime}s 步数:${r.step}`)
})
```



#### 3.2.5 传感器原始数据

本节包含两种不同的数据方式:

| 数据 | 获取方式 | 说明 |
| ---- | -------- | ---- |
| PPG/ACC/PPG Red/IR原始数据 | 历史获取 | APP控制设备开始/停止采集, 采集完成后主动同步历史数据 |
| 睡眠状态数据 | 实时推送 | 设备在睡眠过程中自动推送, APP只需订阅回调 |

> **重要:** PPG/ACC/PPG Red/IR原始数据不支持实时推送, 仅支持历史方式获取; 睡眠状态数据只使用实时推送, 不通过历史原始数据接口获取.
>
> 设备只保存最近一次约1分钟的PPG原始数据, 无论由定时监测还是手动测量触发, 下一次采集都可能覆盖尚未同步的数据; 采集完成后应及时调用 `RwBleSdk.getSensorHistoryRaw()` 同步并持久化数据.
>
> 配置表属性: `isSupportSensorRawPPG` (PPG), `isSupportSensorRawACC` (ACC), `isSupportSensorRawPPGRed` (PPG Red), `isSupportSensorRawIR` (IR), `isSupportSensorRawSleep` (睡眠实时数据).

PPG/ACC/PPG Red/IR历史采集的 `sensorType` 合法组合:

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
>
> **注意:** 控制接口的 `sensorType` 是传感器按位组合值, 返回对象的 `type` 是数据类型, 两者编号定义不同. 例如 `sensorType=1` 表示开启ACC, 而历史数据 `type=1` 表示PPG; `sensorType=5` 表示红光+ACC, 而睡眠实时数据 `type=5` 表示睡眠状态.

##### 3.2.5.0 PPG定时监测

> 配置表属性: `isSupportPPGMonitoring`

`RwBleSdk.setTimedPPG(bean: DrinkReminderBean): Promise<void>`

`RwBleSdk.getTimedPPG(): Promise<DrinkReminderBean>`

> 用法同心率定时监测(3.2.2.2.1)一致.

##### 3.2.5.1 启动与关闭传感器原始数据

> 本接口仅用于控制PPG/ACC/PPG Red/IR历史原始数据采集, 睡眠实时数据无需调用此接口.

方法说明: 

`RwBleSdk.controlSensorRaw(outputType: number, sensorType: number): Promise<void>`

参数说明:

| 参数       | 类型   | 说明         | 值                                     |
| ---------- | ------ | ------------ | -------------------------------------- |
| outputType | number | 输出控制类型 | 1: 开启Sensor输出<br>2: 关闭Sensor输出 |
| sensorType | number | 传感器类型   | 见上方合法组合表                       |

调用示例:

```typescript
// 开启PPG+ACC
await RwBleSdk.controlSensorRaw(1, 3)

// 关闭PPG+ACC
await RwBleSdk.controlSensorRaw(2, 3)
```

`Promise` 完成表示设备已应答本次启动或关闭指令, 不表示历史数据已经同步完成.


##### 3.2.5.2 历史原始数据获取

> PPG/ACC/PPG Red/IR原始数据仅支持历史方式获取. 设备先采集并保存数据, APP后续通过 `RwBleSdk.getSensorHistoryRaw()` 主动同步获取.

方法说明:

`RwBleSdk.getSensorHistoryRaw(): Promise<SensorHistoryRawBean[]>`

`SensorHistoryRawBean` 字段说明:

| 字段           | 类型         | 说明                                      |
| -------------- | ------------ | ----------------------------------------- |
| type           | number       | 数据类型: 1=PPG, 2=ACC, 3=PPG Red, 4=IR |
| sequence       | number       | 数据包序号, 从1开始, 多个传感器共用同一序号 |
| ppgDataList    | number[]     | PPG数据列表, 每项为int32                  |
| accDataList    | AccRawItem[] | ACC数据列表, 每项包含x、y、z (int16)      |
| ppgRedDataList | number[]     | PPG Red数据列表, 每项为int32              |
| irDataList     | number[]     | IR红外数据列表, 每项为int32               |

`AccRawItem` 字段说明:

| 字段 | 类型   | 说明          |
| ---- | ------ | ------------- |
| x    | number | X轴值 (int16) |
| y    | number | Y轴值 (int16) |
| z    | number | Z轴值 (int16) |

调用示例:

```typescript
try {
  const history = await RwBleSdk.getSensorHistoryRaw()
  history.forEach(item => {
    console.log(`类型:${item.type} 序号:${item.sequence}`)
  })
} catch (e) {
  console.error('获取传感器历史失败', JSON.stringify(e))
}
```


##### 3.2.5.3 睡眠状态实时推送

> 睡眠状态数据只支持实时推送. 无需调用 `RwBleSdk.controlSensorRaw()` 启动或关闭; 设备支持此功能时, 会在睡眠过程中自动推送.
>
> 配置表属性: `isSupportSensorRawSleep`.

方法说明:

`RwBleSdk.onSensorRawData(cb: (value: SensorRawDataBean) => void): () => void`

返回说明:

| `SensorRawDataBean`字段 | 类型           | 说明 |
| ----------------------- | -------------- | ---- |
| type                    | number         | 固定为5, 表示睡眠状态数据 |
| sleepDataList           | SleepRawItem[] | 睡眠状态列表, 每项包含 `time` 和 `mode` |

`SleepRawItem` 字段说明:

| 字段 | 类型   | 说明 |
| ---- | ------ | ---- |
| time | number | Unix时间戳, 单位秒(s) |
| mode | number | 睡眠状态: 17=睡眠开始, 34=睡眠结束, 1=深睡, 2=浅睡, 3=清醒, 4=REM |

调用示例:

```typescript
const unsubscribe = RwBleSdk.onSensorRawData((data) => {
  if (data.type !== 5) return
  data.sleepDataList?.forEach(item => {
    console.log(`睡眠时间:${item.time} 状态:${item.mode}`)
  })
})

// 页面退出或不再接收时取消订阅
unsubscribe()
```



## SDK修订记录

**v2.0.0_20260820** (2026.08.20)
- 添加即时屏幕控制功能(3.2.1.27)
- 添加调试、测试用自定义设备时间设置接口 `setDeviceTime`
- 添加授权密码重置功能（3.2.1.26.3）
- 补充获取可用固件及OTA型号、版本校验说明(3.2.3.1)

**v2.0.0_20260807** (2026.08.07)
- 添加设备密码认证功能（3.2.1.26）

**v2.0.0_20260724** (2026.07.24)
- 增加计步明细间隔支持

**v2.0.0_20260716** (2026.07.16)
- HarmonyOS SDK 首版发布


## 联系方式 / 技术支持

- 技术支持邮箱  developer@dhouse88.com
