import { RwBleDevice, SupportMenuBean } from 'rw_ble_sdk';

/** Demo 展示辅助：未支持的状态返回空文本，不在列表占位。 */
export class DevicePresentation {
  /** 同一设备的可见扫描信息改变时，重建该行，避免 ForEach 复用旧文本。 */
  static scanRowKey(device: RwBleDevice): string {
    return JSON.stringify([
      device.deviceId, device.name ?? '', device.mac ?? '', device.uuid ?? '',
      device.rssi ?? 0, device.batteryStatus ?? -1, device.deviceForm ?? -1
    ])
  }

  static batteryStatus(value?: number): string {
    switch (value) {
      case 0: return '未充电'
      case 1: return '充电中'
      case 2: return '充满'
      default: return ''
    }
  }

  static deviceForm(value?: number): string {
    const labels: string[] = ['无屏戒指', '有屏戒指', '无屏手链', '有屏手链', '无屏手环', '有屏手环', '手表']
    return value !== undefined && Number.isInteger(value) && value >= 0 && value < labels.length
      ? labels[value] : ''
  }

  static supports(id: string, menu: SupportMenuBean | null): boolean {
    if (!menu) return false
    switch (id) {
      case 'vibrationControl': return menu.isSupportVibrationControl === true
      case 'customNumber': return menu.isSupportCustomNumberDisplay === true
      case 'countControl': return menu.isSupportCountControl === true
      case 'ppgSampleRate': return menu.isSupportPpgSampleRate === true
      case 'customerModel': return menu.isSupportCustomerModel === true
      case 'muslimCountClean': return menu.isMuslimCountData === true
      default: return false
    }
  }

  static touchAction(keyType: number, touchType: number): string {
    if (keyType === 2) return '跌落提醒'
    if (keyType === 3) return 'SOS 事件'
    if (keyType === 4) return `连续点击 ${touchType} 次`
    if (keyType === 1) {
      const labels: string[] = ['', '单击', '双击', '三击', '长按', '甩动', '松手(Release)']
      if (Number.isInteger(touchType) && touchType >= 1 && touchType < labels.length) return labels[touchType]
    }
    return `未知操作 ${keyType}/${touchType}`
  }

  static hasNewSettings(menu: SupportMenuBean | null): boolean {
    const ids: string[] = ['vibrationControl', 'customNumber', 'countControl', 'ppgSampleRate', 'customerModel', 'muslimCountClean']
    return ids.some((id: string) => DevicePresentation.supports(id, menu))
  }
}
