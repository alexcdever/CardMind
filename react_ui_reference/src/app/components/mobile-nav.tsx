import { StickyNote, Wifi, Settings } from 'lucide-react';
import { cn } from './ui/utils';

interface MobileNavProps {
  activeTab: 'notes' | 'devices' | 'settings';
  onTabChange: (tab: 'notes' | 'devices' | 'settings') => void;
  noteCount: number;
  deviceCount: number;
}

export function MobileNav({ activeTab, onTabChange, noteCount, deviceCount }: MobileNavProps) {
  const tabs = [
    { id: 'notes' as const, icon: StickyNote, label: '笔记', badge: noteCount },
    { id: 'devices' as const, icon: Wifi, label: '设备', badge: deviceCount },
    { id: 'settings' as const, icon: Settings, label: '设置', badge: 0 },
  ];

  return (
    <div className="fixed bottom-0 left-0 right-0 bg-background border-t lg:hidden z-50">
      <nav className="flex items-center justify-around h-16">
        {tabs.map((tab) => {
          const Icon = tab.icon;
          const isActive = activeTab === tab.id;
          
          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              className={cn(
                'flex flex-col items-center justify-center flex-1 h-full gap-1 transition-colors relative',
                isActive ? 'text-primary' : 'text-muted-foreground'
              )}
            >
              <div className="relative">
                <Icon className={cn('size-5', isActive && 'scale-110 transition-transform')} />
                {tab.badge > 0 && (
                  <span className="absolute -top-1 -right-2 bg-primary text-primary-foreground text-xs rounded-full min-w-[18px] h-[18px] flex items-center justify-center px-1">
                    {tab.badge > 99 ? '99+' : tab.badge}
                  </span>
                )}
              </div>
              <span className={cn('text-xs', isActive && 'font-medium')}>{tab.label}</span>
              {isActive && (
                <div className="absolute top-0 left-1/2 -translate-x-1/2 w-12 h-1 bg-primary rounded-b-full" />
              )}
            </button>
          );
        })}
      </nav>
    </div>
  );
}
