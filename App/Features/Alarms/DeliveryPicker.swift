import HabitCore
import SwiftUI

/// "منبه | إشعار فقط": a Form section shared by the alarm editor, the page schedule and the task editor.
struct DeliveryPicker: View {
    @Binding var delivery: AlarmDelivery

    var body: some View {
        Section {
            Picker("طريقة التنبيه", selection: $delivery) {
                Text("منبه").tag(AlarmDelivery.alarm)
                Text("إشعار فقط").tag(AlarmDelivery.notification)
            }
            .pickerStyle(.segmented)
        } header: {
            Text("طريقة التنبيه")
        } footer: {
            Text(delivery == .alarm
                 ? "يرن ويغطي الشاشة مثل منبه الساعة، حتى لو الجوال على الصامت."
                 : "يطلع إشعار عادي بدون رنين ولا شاشة كاملة، ويتبع وضع الصامت والتركيز.")
        }
    }
}
