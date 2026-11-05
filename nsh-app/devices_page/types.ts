// 设备页类型（自 devices_page.tsx 纯结构拆出，声明逐字保留）。

/** 已配对设备行（与 nsh-app/src/lib.rs 的 PairedDeviceDto 镜像一致）。 */
export interface PairedDeviceDto {
  peerId: string;
  name: string;
  lastSeen: string | null;
  lastSyncAt: string | null;
  pairedAt: string;
}

/** mDNS 发现的对端（PeerInfoDto 镜像）。 */
export interface PeerInfoDto {
  deviceId: string;
  ip: string;
  port: number;
  nonce: string;
}

/** 待确认的配对请求（PairingRequestDto 镜像）。 */
export interface PairingRequestDto {
  code: string;
  deviceId: string;
  deviceName: string;
  relayInfo: string;
  ips: string[];
  nonce: string;
}

/** 配对结果（PairingResultDto 镜像）。 */
export interface PairingResultDto {
  peerId: string;
  peerName: string;
}

/** 显示方配对凭证展示（PairingCredentialDisplayDto 镜像）。 */
export interface PairingCredentialDisplayDto {
  code: string;
  credential: string;
  expiresAt: string;
}

/** 设备页后端表面（TSX 侧能注入假实现）。 */
export interface DevicesSource {
  getDeviceId(): Promise<string>;
  getDeviceName(): Promise<string>;
  setDeviceName(name: string): Promise<boolean>;
  localAddrs(): Promise<string[]>;
  listPairedDevices(): Promise<PairedDeviceDto[]>;
  removePairedDevice(peerId: string): Promise<boolean>;
  checkDeviceConnectivity(peerId: string): Promise<number>;
  syncDiscoverPeers(): Promise<PeerInfoDto[]>;
  discoverPeers(): Promise<PeerInfoDto[]>;
  beginPairingAcceptWithAdvertising(): Promise<string>;
  beginPairingCredentialWithAdvertising(): Promise<PairingCredentialDisplayDto>;
  stopPairingAdvertising(): Promise<boolean>;
  acceptPairingRequestWithTimeout(timeoutMs: number): Promise<PairingRequestDto | null>;
  confirmPairing(code: string, request: PairingRequestDto): Promise<PairingResultDto>;
  beginPairingConnect(code: string, target: PeerInfoDto): Promise<PairingResultDto>;
  parsePairingCredential(credential: string): Promise<unknown>;
  beginPairingConnectWithCredential(credential: string): Promise<PairingResultDto>;
  /** 保存配对二维码 PNG：弹系统保存框写文件；返回保存路径，空串 = 用户取消。 */
  savePairingQrPng(credential: string): Promise<string>;
  /** 识别二维码图片：弹系统打开框选图；返回 cm1. 凭证，空串 = 用户取消。 */
  decodePairingQrFile(): Promise<string>;
}
