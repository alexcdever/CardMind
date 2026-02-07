import { useState } from 'react';
import { Card, CardContent, CardHeader, CardTitle } from './ui/card';
import { Badge } from './ui/badge';
import { Button } from './ui/button';
import { Input } from './ui/input';
import { Dialog, DialogContent, DialogHeader, DialogTitle, DialogTrigger } from './ui/dialog';
import { Tabs, TabsContent, TabsList, TabsTrigger } from './ui/tabs';
import { Smartphone, Laptop, Tablet, Wifi, WifiOff, Plus, Check, QrCode, Radar } from 'lucide-react';
import { QRCodeMock } from './qr-code-mock';

export interface Device {
  id: string;
  name: string;
  type: 'phone' | 'laptop' | 'tablet';
  status: 'online' | 'offline';
  lastSeen: number;
}

interface DeviceManagerProps {
  currentDevice: Device;
  pairedDevices: Device[];
  onDeviceNameChange: (name: string) => void;
  onAddDevice: (device: Device) => void;
  onRemoveDevice: (deviceId: string) => void;
}

export function DeviceManager({
  currentDevice,
  pairedDevices,
  onDeviceNameChange,
  onAddDevice,
  onRemoveDevice,
}: DeviceManagerProps) {
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [newDeviceName, setNewDeviceName] = useState('');
  const [selectedType, setSelectedType] = useState<'phone' | 'laptop' | 'tablet'>('laptop');
  const [editingName, setEditingName] = useState(false);
  const [tempName, setTempName] = useState(currentDevice.name);

  const getDeviceIcon = (type: string) => {
    switch (type) {
      case 'phone':
        return <Smartphone className="size-4" />;
      case 'laptop':
        return <Laptop className="size-4" />;
      case 'tablet':
        return <Tablet className="size-4" />;
      default:
        return <Laptop className="size-4" />;
    }
  };

  const handleAddDevice = () => {
    if (newDeviceName.trim()) {
      const newDevice: Device = {
        id: `device-${Date.now()}`,
        name: newDeviceName.trim(),
        type: selectedType,
        status: 'online',
        lastSeen: Date.now(),
      };
      onAddDevice(newDevice);
      setNewDeviceName('');
      setIsDialogOpen(false);
    }
  };

  const handleSaveName = () => {
    if (tempName.trim()) {
      onDeviceNameChange(tempName.trim());
      setEditingName(false);
    }
  };

  return (
    <Card>
      <CardHeader>
        <CardTitle className="flex items-center gap-2">
          <Wifi className="size-5" />
          设备网络
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        {/* 当前设备 */}
        <div>
          <p className="text-sm text-muted-foreground mb-2">当前设备</p>
          <div className="flex items-center gap-3 p-3 bg-primary/10 rounded-lg border border-primary/20">
            {getDeviceIcon(currentDevice.type)}
            {editingName ? (
              <div className="flex-1 flex items-center gap-2">
                <Input
                  value={tempName}
                  onChange={(e) => setTempName(e.target.value)}
                  className="h-8"
                  autoFocus
                />
                <Button size="sm" onClick={handleSaveName}>
                  <Check className="size-4" />
                </Button>
              </div>
            ) : (
              <div className="flex-1">
                <p className="font-medium">{currentDevice.name}</p>
                <p className="text-xs text-muted-foreground">本机 · {currentDevice.id.slice(-8)}</p>
              </div>
            )}
            <Badge variant="default" className="bg-green-600">
              <Wifi className="size-3 mr-1" />
              在线
            </Badge>
            {!editingName && (
              <Button
                variant="ghost"
                size="sm"
                onClick={() => {
                  setEditingName(true);
                  setTempName(currentDevice.name);
                }}
              >
                编辑
              </Button>
            )}
          </div>
        </div>

        {/* 已配对设备 */}
        <div>
          <div className="flex items-center justify-between mb-2">
            <p className="text-sm text-muted-foreground">
              已配对设备 ({pairedDevices.length})
            </p>
            <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
              <DialogTrigger asChild>
                <Button size="sm" variant="outline">
                  <Plus className="size-4 mr-1" />
                  配对设备
                </Button>
              </DialogTrigger>
              <DialogContent className="max-w-md">
                <DialogHeader>
                  <DialogTitle>配对新设备</DialogTitle>
                </DialogHeader>
                <Tabs defaultValue="scan" className="w-full">
                  <TabsList className="grid w-full grid-cols-2">
                    <TabsTrigger value="scan">
                      <QrCode className="size-4 mr-2" />
                      扫描二维码
                    </TabsTrigger>
                    <TabsTrigger value="nearby">
                      <Radar className="size-4 mr-2" />
                      附近设备
                    </TabsTrigger>
                  </TabsList>
                  
                  <TabsContent value="scan" className="space-y-4 py-4">
                    <div className="flex flex-col items-center">
                      <QRCodeMock 
                        data={`device://${currentDevice.id}`}
                        size={240}
                      />
                      <p className="text-sm text-muted-foreground mt-4 text-center">
                        在另一台设备上打开此应用，扫描此二维码即可配对
                      </p>
                    </div>
                  </TabsContent>
                  
                  <TabsContent value="nearby" className="space-y-4 py-4">
                    <div className="space-y-4">
                      <div>
                        <label className="text-sm font-medium mb-2 block">设备名称</label>
                        <Input
                          value={newDeviceName}
                          onChange={(e) => setNewDeviceName(e.target.value)}
                          placeholder="输入设备名称"
                          onKeyDown={(e) => e.key === 'Enter' && handleAddDevice()}
                        />
                      </div>
                      <div>
                        <label className="text-sm font-medium mb-2 block">设备类型</label>
                        <div className="grid grid-cols-3 gap-2">
                          {(['laptop', 'phone', 'tablet'] as const).map((type) => (
                            <Button
                              key={type}
                              variant={selectedType === type ? 'default' : 'outline'}
                              onClick={() => setSelectedType(type)}
                              className="flex flex-col h-auto py-3"
                            >
                              {getDeviceIcon(type)}
                              <span className="mt-1 text-xs">
                                {type === 'laptop' ? '电脑' : type === 'phone' ? '手机' : '平板'}
                              </span>
                            </Button>
                          ))}
                        </div>
                      </div>
                      <Button onClick={handleAddDevice} className="w-full">
                        <Plus className="size-4 mr-2" />
                        添加设备
                      </Button>
                      <div className="border-t pt-4 space-y-2">
                        <p className="text-sm text-muted-foreground flex items-center gap-2">
                          <Radar className="size-4 animate-pulse" />
                          正在搜索局域网设备...
                        </p>
                        <div className="text-xs text-muted-foreground bg-muted p-3 rounded">
                          <p className="mb-1">💡 提示：</p>
                          <ul className="list-disc list-inside space-y-1">
                            <li>确保设备连接到同一 WiFi 网络</li>
                            <li>允许应用访问本地网络权限</li>
                          </ul>
                        </div>
                      </div>
                    </div>
                  </TabsContent>
                </Tabs>
              </DialogContent>
            </Dialog>
          </div>

          <div className="space-y-2">
            {pairedDevices.length === 0 ? (
              <div className="text-center py-8 text-muted-foreground">
                <WifiOff className="size-8 mx-auto mb-2 opacity-50" />
                <p className="text-sm">暂无配对设备</p>
                <p className="text-xs">点击上方按钮配对新设备</p>
              </div>
            ) : (
              pairedDevices.map((device) => (
                <div
                  key={device.id}
                  className="flex items-center gap-3 p-3 bg-muted/50 rounded-lg border"
                >
                  {getDeviceIcon(device.type)}
                  <div className="flex-1">
                    <p className="font-medium">{device.name}</p>
                    <p className="text-xs text-muted-foreground">
                      {new Date(device.lastSeen).toLocaleString('zh-CN')}
                    </p>
                  </div>
                  <Badge
                    variant={device.status === 'online' ? 'default' : 'secondary'}
                    className={
                      device.status === 'online' ? 'bg-green-600' : 'bg-gray-500'
                    }
                  >
                    {device.status === 'online' ? '在线' : '离线'}
                  </Badge>
                  <Button
                    variant="ghost"
                    size="sm"
                    onClick={() => onRemoveDevice(device.id)}
                  >
                    移除
                  </Button>
                </div>
              ))
            )}
          </div>
        </div>
      </CardContent>
    </Card>
  );
}