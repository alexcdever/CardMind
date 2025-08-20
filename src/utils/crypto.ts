import sodium from 'libsodium-wrappers';

// 等待sodium库初始化
sodium.ready.then(() => {
  console.log('libsodium-wrappers initialized');
}).catch((error: Error) => {
  console.error('libsodium-wrappers initialization failed:', error);
});

export const Crypto = {
  // 加密文本
  encrypt: (text: string, key: Uint8Array): { nonce: Uint8Array; cipher: Uint8Array } => {
    const nonce = sodium.randombytes_buf(sodium.crypto_secretbox_NONCEBYTES);
    const cipher = sodium.crypto_secretbox_easy(text, nonce, key);
    return { nonce, cipher };
  },

  // 解密文本  
  decrypt: (nonce: Uint8Array, cipher: Uint8Array, key: Uint8Array): string => {
    const result = sodium.crypto_secretbox_open_easy(cipher, nonce, key, 'text');
    if (!result) {
      throw new Error('解密失败：无效的密钥或数据');
    }
    return result as string;
  },

  // 从密码派生密钥
  deriveKey: (passphrase: string): Uint8Array => {
    return sodium.crypto_generichash(32, passphrase);
  },

  // 生成随机密钥
  generateKey: (): Uint8Array => {
    return sodium.randombytes_buf(sodium.crypto_secretbox_KEYBYTES);
  }
};
