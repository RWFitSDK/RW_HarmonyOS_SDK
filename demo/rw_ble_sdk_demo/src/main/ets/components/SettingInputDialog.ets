@CustomDialog
export struct SettingInputDialog {
  controller?: CustomDialogController
  title: string = ''
  hint: string = ''
  initialValue: string = ''
  numeric: boolean = false
  onConfirm: (value: string) => void = (_value: string): void => {}
  @State private value: string = ''

  aboutToAppear(): void {
    this.value = this.initialValue
  }

  build() {
    Column({ space: 16 }) {
      Text(this.title).fontSize(19).fontWeight(FontWeight.Bold).width('100%')
      TextInput({ text: this.value, placeholder: this.hint })
        .type(this.numeric ? InputType.Number : InputType.Normal)
        .onChange((value: string) => this.value = value)
      Row({ space: 12 }) {
        Button('取消').layoutWeight(1).backgroundColor('#EDF0EE').fontColor('#26312C')
          .onClick(() => this.controller?.close())
        Button('发送').layoutWeight(1).backgroundColor('#0C9B6C')
          .onClick(() => {
            this.controller?.close()
            this.onConfirm(this.value)
          })
      }.width('100%')
    }.padding(24).width('100%')
  }
}
