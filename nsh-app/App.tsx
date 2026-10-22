import { mount, signal, Text, View } from "nsh";
import { App, Backend, Bridge } from "app/native";

function Root() {
  const device = signal("设备ID：(调用中…)");
  const last = signal("最近事件：(还没收到)");
  (async () => {
    const id = await Backend.deviceId();
    device.set(`设备ID：${id}`);
  })();
  return (
    <View style={{ flex: 1, padding: 12, gap: 8 }}>
      <App />
      <Text>{device()}</Text>
      <Bridge
        onSyncProgress={(n) => last.set(`最近事件：SyncProgress(${n})`)}
        onPeerFound={(name) => last.set(`最近事件：PeerFound(${name})`)}
      />
      <Text>{last()}</Text>
    </View>
  );
}

mount(Root);
