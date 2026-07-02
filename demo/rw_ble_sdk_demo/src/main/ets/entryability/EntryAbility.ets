import { AbilityConstant, UIAbility, Want, abilityAccessCtrl, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

export default class EntryAbility extends UIAbility {
  onCreate(_want: Want, _launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(0x0000, 'RwBleDemo', 'EntryAbility onCreate')
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    windowStage.loadContent('pages/HomePage', (err) => {
      if (err.code) {
        hilog.error(0x0000, 'RwBleDemo', 'loadContent failed %{public}s', JSON.stringify(err))
      }
    })
    // Request the BLE permission up front so the scan page works without an in-flow prompt.
    this.requestBluetoothPermission()
  }

  private async requestBluetoothPermission(): Promise<void> {
    try {
      const perms: Array<Permissions> = ['ohos.permission.ACCESS_BLUETOOTH']
      const atm = abilityAccessCtrl.createAtManager()
      await atm.requestPermissionsFromUser(this.context, perms)
    } catch (e) {
      hilog.error(0x0000, 'RwBleDemo', 'requestBluetoothPermission failed %{public}s', JSON.stringify(e))
    }
  }
}
