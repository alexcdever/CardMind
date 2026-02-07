import { useEffect, useState } from 'react';
import { Badge } from './ui/badge';
import { RefreshCw, Check, AlertCircle } from 'lucide-react';

interface SyncStatusProps {
  lastSyncTime: number;
  isSyncing: boolean;
  syncError?: string;
}

export function SyncStatus({ lastSyncTime, isSyncing, syncError }: SyncStatusProps) {
  const [timeSinceSync, setTimeSinceSync] = useState('');

  useEffect(() => {
    const updateTime = () => {
      if (!lastSyncTime) {
        setTimeSinceSync('从未同步');
        return;
      }

      const seconds = Math.floor((Date.now() - lastSyncTime) / 1000);
      if (seconds < 5) {
        setTimeSinceSync('刚刚同步');
      } else if (seconds < 60) {
        setTimeSinceSync(`${seconds}秒前`);
      } else {
        const minutes = Math.floor(seconds / 60);
        setTimeSinceSync(`${minutes}分钟前`);
      }
    };

    updateTime();
    const interval = setInterval(updateTime, 1000);
    return () => clearInterval(interval);
  }, [lastSyncTime]);

  if (syncError) {
    return (
      <Badge variant="destructive" className="gap-1">
        <AlertCircle className="size-3" />
        同步失败
      </Badge>
    );
  }

  if (isSyncing) {
    return (
      <Badge variant="secondary" className="gap-1">
        <RefreshCw className="size-3 animate-spin" />
        同步中...
      </Badge>
    );
  }

  return (
    <Badge variant="outline" className="gap-1">
      <Check className="size-3 text-green-600" />
      {timeSinceSync}
    </Badge>
  );
}
