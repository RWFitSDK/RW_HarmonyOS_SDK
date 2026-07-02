import preferences from '@ohos.data.preferences';
import { common } from '@kit.AbilityKit';
import { RwBleDevice } from 'rw_ble_sdk';

const PREF_NAME = 'rwfit_demo'
const KEY_DEVICE = 'rwfit_saved_device'

export class SavedDeviceStore {
  static async load(ctx: common.Context): Promise<RwBleDevice | null> {
    try {
      const pref = await preferences.getPreferences(ctx, PREF_NAME)
      const text = await pref.get(KEY_DEVICE, '') as string
      if (!text) return null
      return JSON.parse(text) as RwBleDevice
    } catch (_e) {
      return null
    }
  }

  static async save(ctx: common.Context, device: RwBleDevice): Promise<void> {
    try {
      const pref = await preferences.getPreferences(ctx, PREF_NAME)
      await pref.put(KEY_DEVICE, JSON.stringify(device))
      await pref.flush()
    } catch (_e) {
      // best-effort persistence; ignore storage errors
    }
  }

  static async clear(ctx: common.Context): Promise<void> {
    try {
      const pref = await preferences.getPreferences(ctx, PREF_NAME)
      await pref.delete(KEY_DEVICE)
      await pref.flush()
    } catch (_e) {
      // best-effort clear; ignore storage errors
    }
  }
}
