import { mount, signal, Text, View } from "nsh";
import { App, Backend } from "app/native";

function Root() {
  const device = signal("设备ID：(调用中…)");
  (async () => {
    const id = await Backend.deviceId();
    device.set(`设备ID：${id}`);
  })();
  return (
    <View style={{ flex: 1, padding: 12, gap: 8 }}>
      <App />
      <Text>{device()}</Text>
    </View>
  );
}

mount(Root);
