import sodium from 'libsodium-wrappers';

// 等待sodium库初始化
await sodium.ready;

export const Crypto = {
  // 加密文本
  encrypt: (text: string, key: Uint8Array): { nonce: Uint8Array; cipher: Uint8Array } => {
    const nonce = sodium.randombytes_buf(sodium.crypto_secretbox_NONCEBYTES);
    const cipher = sodium.crypto_secretbox_easy(text, nonce, key);
    return { nonce, cipher };
  },

  // 解密文本  
  decrypt: (nonce: Uint8Array, cipher: Uint8Array, key: Uint8Array): string => {
    return sodium.crypto_secretbox_open_easy(cipher, nonce, key, 'text');
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
