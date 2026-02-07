import { Card, CardContent, CardHeader, CardTitle, CardDescription } from './ui/card';
import { Button } from './ui/button';
import { Switch } from './ui/switch';
import { Label } from './ui/label';
import { Separator } from './ui/separator';
import { Settings, Database, Bell, Palette, Info } from 'lucide-react';

export function SettingsPanel() {
  return (
    <div className="space-y-4">
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Settings className="size-5" />
            应用设置
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-6">
          {/* 通知设置 */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <Label className="flex items-center gap-2">
                  <Bell className="size-4" />
                  同步通知
                </Label>
                <p className="text-sm text-muted-foreground">
                  当笔记被其他设备修改时通知你
                </p>
              </div>
              <Switch defaultChecked />
            </div>
            <Separator />
          </div>

          {/* 外观设置 */}
          <div className="space-y-3">
            <div className="flex items-center justify-between">
              <div className="space-y-0.5">
                <Label className="flex items-center gap-2">
                  <Palette className="size-4" />
                  深色模式
                </Label>
                <p className="text-sm text-muted-foreground">
                  使用深色主题保护眼睛
                </p>
              </div>
              <Switch />
            </div>
            <Separator />
          </div>

          {/* 数据设置 */}
          <div className="space-y-3">
            <div className="space-y-0.5">
              <Label className="flex items-center gap-2">
                <Database className="size-4" />
                数据管理
              </Label>
              <p className="text-sm text-muted-foreground">
                管理本地存储的笔记数据
              </p>
            </div>
            <div className="flex gap-2">
              <Button variant="outline" size="sm">
                导出数据
              </Button>
              <Button variant="outline" size="sm">
                导入数据
              </Button>
              <Button variant="destructive" size="sm">
                清空数据
              </Button>
            </div>
          </div>
        </CardContent>
      </Card>

      {/* 关于 */}
      <Card>
        <CardHeader>
          <CardTitle className="flex items-center gap-2">
            <Info className="size-5" />
            关于应用
          </CardTitle>
        </CardHeader>
        <CardContent className="space-y-2 text-sm text-muted-foreground">
          <p><strong>版本:</strong> 1.0.0</p>
          <p><strong>技术栈:</strong> Flutter + Rust</p>
          <p><strong>P2P 通信:</strong> libp2p</p>
          <p><strong>CRDT 引擎:</strong> loro</p>
          <Separator className="my-3" />
          <p className="text-xs">
            这是一个分布式笔记应用的 UI 原型参考。实际应用将使用 Flutter 实现跨平台界面，
            Rust + libp2p 实现局域网 P2P 通信，loro 实现无冲突协同编辑。
          </p>
        </CardContent>
      </Card>
    </div>
  );
}
