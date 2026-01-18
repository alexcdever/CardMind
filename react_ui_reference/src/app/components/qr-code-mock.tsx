interface QRCodeMockProps {
  data: string;
  size?: number;
}

export function QRCodeMock({ data, size = 200 }: QRCodeMockProps) {
  // 模拟二维码显示，实际 Flutter 应用中应使用 qr_flutter 包
  return (
    <div className="flex flex-col items-center gap-3">
      <div 
        className="bg-white p-4 rounded-lg border-2 border-border"
        style={{ width: size, height: size }}
      >
        <div className="w-full h-full bg-gradient-to-br from-gray-900 via-gray-700 to-gray-900 rounded flex items-center justify-center relative overflow-hidden">
          {/* 模拟二维码图案 */}
          <div className="absolute inset-0 grid grid-cols-8 gap-px p-2">
            {Array.from({ length: 64 }).map((_, i) => (
              <div
                key={i}
                className={`rounded-sm ${
                  Math.random() > 0.5 ? 'bg-white' : 'bg-transparent'
                }`}
              />
            ))}
          </div>
          {/* 中心 Logo */}
          <div className="relative z-10 bg-white rounded-lg p-2">
            <div className="size-8 bg-primary rounded" />
          </div>
        </div>
      </div>
      <p className="text-xs text-muted-foreground text-center max-w-[200px]">
        {data}
      </p>
    </div>
  );
}
