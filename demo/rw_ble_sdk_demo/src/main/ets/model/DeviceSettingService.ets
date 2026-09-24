import {
  AlarmRemainderBean,
  BrightScreenBean,
  BrightScreenLedBean,
  BrightScreenTimeBean,
  DndBean,
  DrinkReminderBean,
  RwBleSdk
} from 'rw_ble_sdk';

export class DeviceSettingService {
  static canGet(id: string): boolean {
    return id !== 'findDevice' && id !== 'takePhoto' && id !== 'powerOff'
  }

  static pickerOptions(id: string): Array<string> {
    if (DeviceSettingService.monitorType(id).length > 0) return ['关闭', '每 30 分钟', '每 60 分钟']
    switch (id) {
      case 'dnd':
      case 'screenSleep': return ['关闭', '22:00–08:00', '全天开启']
      case 'brightDuration': return ['5 秒', '10 秒', '15 秒', '20 秒', '30 秒']
      case 'raiseToWake': return ['关闭', '08:00–22:00', '全天开启']
      case 'ledLevel': return ['关闭', '亮度 1', '亮度 2', '亮度 3']
      case 'wearHand': return ['左手', '右手']
      case 'takePhoto': return ['进入遥控拍照', '退出遥控拍照']
      case 'heartRateAlert': return ['关闭', '上限 120 bpm', '上限 140 bpm', '上限 160 bpm']
      case 'bloodOxygenAlert': return ['关闭', '下限 90%', '下限 92%', '下限 94%']
      case 'vibrationCount': return ['关闭', '低强度 · 1 次', '中强度 · 2 次', '高强度 · 3 次']
      case 'alarmVibration': return ['不震动', '1 次', '2 次', '3 次', '4 次', '5 次', '6 次']
      case 'vibrationInterval': return ['100 ms', '200 ms', '300 ms', '500 ms', '1000 ms']
      case 'countReminder': return ['关闭', '30 分钟', '60 分钟', '90 分钟', '120 分钟']
      case 'screenControl': return ['立即息屏', '立即亮屏']
      case 'measureUnit': return ['公制', '英制']
      case 'fallDetect':
      case 'rememberSwitch': return ['关闭', '开启']
      case 'muslimTimeMode': return ['唤醒先显示时间', '不显示时间', '休眠 10 分钟后显示']
      case 'sedentary':
      case 'drink': return ['关闭', '每 30 分钟', '每 60 分钟', '每 90 分钟', '每 120 分钟']
      default: return []
    }
  }

  static defaultPickerIndex(id: string): number {
    if (DeviceSettingService.monitorType(id).length > 0) return 2
    switch (id) {
      case 'dnd':
      case 'screenSleep':
      case 'raiseToWake': return 1
      case 'brightDuration': return 1
      case 'ledLevel': return 2
      case 'wearHand': return 1
      case 'heartRateAlert': return 3
      case 'bloodOxygenAlert': return 3
      case 'vibrationCount': return 3
      case 'alarmVibration': return 3
      case 'vibrationInterval': return 3
      case 'countReminder': return 2
      case 'screenControl': return 1
      case 'measureUnit': return 0
      case 'fallDetect':
      case 'rememberSwitch': return 1
      case 'muslimTimeMode': return 2
      case 'sedentary':
      case 'drink': return 2
      default: return 0
    }
  }

  static async setAlarmTime(hour: number, minute: number): Promise<string> {
    const alarm: AlarmRemainderBean = {
      alarmId: 0,
      isOpen: true,
      repeatModel: [0, 1, 1, 1, 1, 1, 0],
      startHour: hour,
      startMin: minute,
      alarmTag: ''
    }
    await RwBleSdk.setAlarm([alarm])
    return `已设置工作日 ${DeviceSettingService.twoDigits(hour)}:${DeviceSettingService.twoDigits(minute)} 闹钟`
  }

  static async setSelected(id: string, index: number): Promise<string> {
    const monitor = DeviceSettingService.monitorType(id)
    if (monitor.length > 0) {
      const intervals: Array<number> = [0, 30, 60]
      const interval = intervals[index] ?? 60
      await DeviceSettingService.setMonitoring(monitor, interval)
      return interval > 0 ? `已开启，每 ${interval} 分钟监测` : '已关闭监测'
    }
    switch (id) {
      case 'dnd': {
        const bean: DndBean = index === 0
          ? { isOpen: false, startHour: 22, startMin: 0, endHour: 8, endMin: 0 }
          : index === 2
            ? { isOpen: true, startHour: 0, startMin: 0, endHour: 23, endMin: 59 }
            : { isOpen: true, startHour: 22, startMin: 0, endHour: 8, endMin: 0 }
        await RwBleSdk.setDnd(bean)
        return DeviceSettingService.pickerLabel(id, index)
      }
      case 'screenSleep': {
        const bean: BrightScreenTimeBean = index === 0
          ? { timeSecond: 10, isOpen: false, startHour: 22, startMin: 0, endHour: 8, endMin: 0 }
          : index === 2
            ? { timeSecond: 10, isOpen: true, startHour: 0, startMin: 0, endHour: 23, endMin: 59 }
            : { timeSecond: 10, isOpen: true, startHour: 22, startMin: 0, endHour: 8, endMin: 0 }
        await RwBleSdk.setRingBrightScreenSleepTime(bean)
        return DeviceSettingService.pickerLabel(id, index)
      }
      case 'brightDuration': {
        const values: Array<number> = [5, 10, 15, 20, 30]
        const seconds = values[index] ?? 10
        await RwBleSdk.setBrightScreenTime(seconds)
        return `亮屏时长已设为 ${seconds} 秒`
      }
      case 'raiseToWake': {
        const bean: BrightScreenBean = index === 0
          ? { isOpen: false, startHour: 8, startMin: 0, endHour: 22, endMin: 0 }
          : index === 2
            ? { isOpen: true, startHour: 0, startMin: 0, endHour: 23, endMin: 59 }
            : { isOpen: true, startHour: 8, startMin: 0, endHour: 22, endMin: 0 }
        await RwBleSdk.setRaiseBrightScreen(bean)
        return DeviceSettingService.pickerLabel(id, index)
      }
      case 'ledLevel': {
        const level = index >= 0 && index <= 3 ? index : 2
        const bean: BrightScreenLedBean = { isOpen: level > 0, lcdLevel: level }
        await RwBleSdk.setRingLedLevel(bean)
        return level > 0 ? `LED 亮度已设为 ${level}` : 'LED 已关闭'
      }
      case 'wearHand': {
        const rightHand = index === 1
        await RwBleSdk.setRingWearHand(rightHand)
        return `佩戴位置已设为${rightHand ? '右手' : '左手'}`
      }
      case 'takePhoto': {
        const enabled = index === 0
        await RwBleSdk.controlTakePhoto(enabled ? 1 : 0)
        return enabled ? '已进入遥控拍照模式' : '已退出遥控拍照模式'
      }
      case 'heartRateAlert': {
        const values: Array<number> = [0, 120, 140, 160]
        const value = values[index] ?? 160
        await RwBleSdk.setHrAlert(value > 0 ? 1 : 0, value || 140, 0xFF)
        return value > 0 ? `心率报警上限已设为 ${value} bpm` : '心率报警已关闭'
      }
      case 'bloodOxygenAlert': {
        const values: Array<number> = [0, 90, 92, 94]
        const value = values[index] ?? 94
        await RwBleSdk.setBoAlert(value > 0 ? 1 : 0, value || 94)
        return value > 0 ? `血氧报警下限已设为 ${value}%` : '血氧报警已关闭'
      }
      case 'vibrationCount': {
        const level = index >= 0 && index <= 3 ? index : 3
        await RwBleSdk.setVibrationCount(level, level)
        return level > 0 ? `震动已设为 ${level} 次` : '震动已关闭'
      }
      case 'alarmVibration': {
        const count = index >= 0 && index <= 6 ? index : 3
        await RwBleSdk.setAlarmVibrationDuration(count)
        return count > 0 ? `闹钟震动已设为 ${count} 次` : '闹钟震动已关闭'
      }
      case 'vibrationInterval': {
        const values: Array<number> = [100, 200, 300, 500, 1000]
        const value = values[index] ?? 500
        await RwBleSdk.setVibrationInterval(value)
        return `震动间隔已设为 ${value} ms`
      }
      case 'countReminder': {
        const values: Array<number> = [0, 30, 60, 90, 120]
        const value = values[index] ?? 60
        await RwBleSdk.setCountReminderInterval(value)
        return value > 0 ? `计数提醒已设为 ${value} 分钟` : '计数提醒已关闭'
      }
      case 'screenControl': {
        const isOn = index === 1
        await RwBleSdk.setScreenOn(isOn)
        return isOn ? '当前已亮屏' : '当前已息屏'
      }
      case 'measureUnit': {
        const type = index === 1 ? 1 : 0
        await RwBleSdk.setMeasureUnit(type)
        return type === 1 ? '当前为英制' : '当前为公制'
      }
      case 'fallDetect': {
        const enabled = index === 1
        await RwBleSdk.setFallDetect(enabled ? 1 : 0)
        return enabled ? '跌落检测已开启' : '跌落检测已关闭'
      }
      case 'sedentary':
      case 'drink': {
        const durations: Array<number> = [0, 30, 60, 90, 120]
        const duration = durations[index] ?? 60
        const bean: DrinkReminderBean = {
          isOpen: duration > 0,
          remindDuration: duration > 0 ? duration : 60,
          startHour: id === 'sedentary' ? 9 : 8,
          startMin: 0,
          endHour: id === 'sedentary' ? 18 : 22,
          endMin: 0
        }
        if (id === 'sedentary') {
          await RwBleSdk.setSedentaryRemind(bean)
        } else {
          await RwBleSdk.setDrinkRemind(bean)
        }
        return duration > 0
          ? `${id === 'sedentary' ? '久坐' : '喝水'}提醒已开启，每 ${duration} 分钟`
          : `${id === 'sedentary' ? '久坐' : '喝水'}提醒已关闭`
      }
      case 'rememberSwitch': {
        const enabled = index === 1
        await RwBleSdk.setMuslimCountSwitch(enabled ? 1 : 0)
        return enabled ? '赞念功能已开启' : '赞念功能已关闭'
      }
      case 'muslimTimeMode': {
        const mode = index >= 0 && index <= 2 ? index + 1 : 3
        await RwBleSdk.setMuslimTimeDisplayMode(mode)
        return DeviceSettingService.pickerLabel(id, index)
      }
      default:
        throw new Error('暂不支持设置此功能')
    }
  }

  static async get(id: string): Promise<string> {
    const monitor = DeviceSettingService.monitorType(id)
    if (monitor.length > 0) return JSON.stringify(await DeviceSettingService.getMonitoring(monitor))
    switch (id) {
      case 'alarm': return JSON.stringify(await RwBleSdk.getAlarmRemind())
      case 'dnd': return JSON.stringify(await RwBleSdk.getDnd())
      case 'screenSleep': return JSON.stringify(await RwBleSdk.getRingBrightScreenSleepTime())
      case 'brightDuration': return JSON.stringify(await RwBleSdk.getBrightScreenTime())
      case 'raiseToWake': return JSON.stringify(await RwBleSdk.getRaiseBrightScreen())
      case 'ledLevel': return JSON.stringify(await RwBleSdk.getRingLedLevel())
      case 'wearHand': return `${await RwBleSdk.getRingWearDir()}`
      case 'heartRateAlert': return JSON.stringify(await RwBleSdk.getHrAlert())
      case 'bloodOxygenAlert': return JSON.stringify(await RwBleSdk.getBoAlert())
      case 'vibrationCount': return JSON.stringify(await RwBleSdk.getVibrationCount())
      case 'alarmVibration': return `${await RwBleSdk.getAlarmVibrationDuration()} 次`
      case 'vibrationInterval': return `${await RwBleSdk.getVibrationInterval()} ms`
      case 'countReminder': return `${await RwBleSdk.getCountReminderInterval()} 分钟`
      case 'screenControl': return await RwBleSdk.getScreenOn() ? '当前亮屏' : '当前息屏'
      case 'measureUnit': return (await RwBleSdk.getMeasureUnit()) === 1 ? '当前为英制' : '当前为公制'
      case 'fallDetect': return (await RwBleSdk.getFallDetect()) === 1 ? '已开启' : '已关闭'
      case 'sedentary': {
        const bean = await RwBleSdk.getSedentaryRemind()
        return DeviceSettingService.reminderLabel('久坐', bean)
      }
      case 'drink': {
        const bean = await RwBleSdk.getDrinkRemind()
        return DeviceSettingService.reminderLabel('喝水', bean)
      }
      case 'rememberSwitch': return (await RwBleSdk.getMuslimCountSwitch()) === 1 ? '已开启' : '已关闭'
      case 'muslimTimeMode': return `模式 ${await RwBleSdk.getMuslimTimeDisplayMode()}`
      default: throw new Error('此功能没有可读取的配置')
    }
  }

  private static monitorType(id: string): string {
    switch (id) {
      case 'heartRateMonitoring': return 'hr'
      case 'bloodOxygenMonitoring': return 'bo'
      case 'hrvMonitoring': return 'hrv'
      case 'stressMonitoring': return 'stress'
      case 'bloodPressureMonitoring': return 'bp'
      case 'bloodSugarMonitoring': return 'sugar'
      case 'temperatureMonitoring': return 'temp'
      case 'ppgMonitoring': return 'ppg'
      default: return ''
    }
  }

  private static pickerLabel(id: string, index: number): string {
    const options = DeviceSettingService.pickerOptions(id)
    return options[index] ?? '设置成功'
  }

  private static twoDigits(value: number): string {
    return value < 10 ? `0${value}` : `${value}`
  }

  private static reminderLabel(name: string, bean: DrinkReminderBean): string {
    if (!bean.isOpen) return `${name}提醒已关闭`
    return `${name}提醒 ${DeviceSettingService.twoDigits(bean.startHour)}:${DeviceSettingService.twoDigits(bean.startMin)}` +
      `–${DeviceSettingService.twoDigits(bean.endHour)}:${DeviceSettingService.twoDigits(bean.endMin)} / 每 ${bean.remindDuration} 分钟`
  }

  private static monitoringBean(interval: number): DrinkReminderBean {
    return {
      isOpen: interval > 0,
      remindDuration: interval > 0 ? interval : 60,
      startHour: 0,
      startMin: 0,
      endHour: 23,
      endMin: 59
    }
  }

  private static async setMonitoring(type: string, interval: number): Promise<void> {
    const bean = DeviceSettingService.monitoringBean(interval)
    switch (type) {
      case 'hr': await RwBleSdk.setTimedHeartRate(bean); return
      case 'bo': await RwBleSdk.setTimedBloodOxygen(bean); return
      case 'hrv': await RwBleSdk.setTimedHRV(bean); return
      case 'stress': await RwBleSdk.setTimedStress(bean); return
      case 'bp': await RwBleSdk.setTimedBloodPressure(bean); return
      case 'sugar': await RwBleSdk.setTimedBloodSugar(bean); return
      case 'temp': await RwBleSdk.setTimedBodyTemperature(bean); return
      case 'ppg': await RwBleSdk.setTimedPPG(bean); return
      default: throw new Error('未知监测类型')
    }
  }

  private static async getMonitoring(type: string): Promise<DrinkReminderBean> {
    switch (type) {
      case 'hr': return RwBleSdk.getTimedHeartRate()
      case 'bo': return RwBleSdk.getTimedBloodOxygen()
      case 'hrv': return RwBleSdk.getTimedHRV()
      case 'stress': return RwBleSdk.getTimedStress()
      case 'bp': return RwBleSdk.getTimedBloodPressure()
      case 'sugar': return RwBleSdk.getTimedBloodSugar()
      case 'temp': return RwBleSdk.getTimedBodyTemperature()
      case 'ppg': return RwBleSdk.getTimedPPG()
      default: throw new Error('未知监测类型')
    }
  }
}
