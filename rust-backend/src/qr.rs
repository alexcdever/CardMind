//! 配对二维码（QR 图片保存/识别任务）。
//!
//! 两条系统对话框路径 + 一个纯函数：
//! - [`render_credential_qr_png`]：把 `cm1.` 配对凭证渲染为二维码 PNG 字节
//!   （纯函数、不弹窗，供测试与 save 路径共用）；
//! - [`save_pairing_qr_png`]：渲染后弹系统「保存」对话框写 PNG；
//! - [`decode_pairing_qr_file`]：弹系统「打开」对话框选图 → 灰度化 → rqrr 识别。
//!
//! 对话框取消约定：返回 `Ok("")`（空串），不是 `Err`——TSX 侧据此区分
//! 「用户取消」与「真错误」。

use anyhow::Context;

/// 把 `cm1.` 配对凭证渲染为二维码 PNG 字节（纯函数，不弹窗）。
///
/// `qrcode` 以 `default-features = false` 引入（契约锁定，`image`/`svg`
/// renderer 未启用），故这里手工铺像素：取模块矩阵（`width()` + `to_colors()`，
/// 含四周静态区）按 cell 放大到 ≥320px 的灰度图，再 PNG 编码。
pub fn render_credential_qr_png(credential: &str) -> anyhow::Result<Vec<u8>> {
    let code = qrcode::QrCode::new(credential.as_bytes()).context("生成二维码失败")?;
    let modules = code.width() as u32;
    let colors = code.to_colors();
    const QUIET: u32 = 4; // 静态区宽度（模块数，QR 规范要求 ≥4）
    let cell = std::cmp::max(1, 320u32.div_ceil(modules + QUIET * 2));
    let size = (modules + QUIET * 2) * cell;
    let mut img = image::GrayImage::from_pixel(size, size, image::Luma([255u8]));
    for (i, c) in colors.iter().enumerate() {
        if *c != qrcode::Color::Dark {
            continue;
        }
        let mx = (i as u32) % modules;
        let my = (i as u32) / modules;
        let x0 = (mx + QUIET) * cell;
        let y0 = (my + QUIET) * cell;
        for dy in 0..cell {
            for dx in 0..cell {
                img.put_pixel(x0 + dx, y0 + dy, image::Luma([0u8]));
            }
        }
    }
    let mut png = std::io::Cursor::new(Vec::new());
    image::DynamicImage::ImageLuma8(img)
        .write_to(&mut png, image::ImageFormat::Png)
        .context("二维码 PNG 编码失败")?;
    Ok(png.into_inner())
}

/// 「保存二维码图片」：渲染 `cm1.` 凭证 → 系统保存对话框 → 写 PNG。
///
/// 返回 `Ok(路径)`；用户取消返回 `Ok("")`（约定值，非错误）。
pub fn save_pairing_qr_png(credential: String) -> Result<String, String> {
    let png = render_credential_qr_png(&credential).map_err(|e| format!("{e:#}"))?;
    let Some(path) = rfd::FileDialog::new()
        .add_filter("PNG 图片", &["png"])
        .set_file_name("cardmind-pairing-qr.png")
        .save_file()
    else {
        return Ok(String::new());
    };
    std::fs::write(&path, &png)
        .map_err(|e| format!("写入 {} 失败：{e:#}", path.display()))?;
    Ok(path.to_string_lossy().into_owned())
}

/// 「识别二维码图片」：系统打开对话框选图 → 解码二维码文本（`cm1.` 凭证）。
///
/// 返回 `Ok(二维码文本)`；用户取消返回 `Ok("")`（约定值，非错误）；
/// 解不出二维码返回可读 `Err`。凭证校验/连接由调用方负责。
pub fn decode_pairing_qr_file() -> Result<String, String> {
    let Some(path) = rfd::FileDialog::new()
        // 只放 png：本 crate 的 image 仅启 png 解码 feature（见 decode_qr_bytes），
        // 列出 jpg/webp 会让用户选了也解不出且文案误导。
        .add_filter("PNG 图片", &["png"])
        .pick_file()
    else {
        return Ok(String::new());
    };
    let bytes =
        std::fs::read(&path).map_err(|e| format!("读取 {} 失败：{e:#}", path.display()))?;
    decode_qr_bytes(&bytes)
}

/// 图片字节 → 二维码文本（核心逻辑，往返测试直接覆盖，不弹窗）。
///
/// `image::load_from_memory` 按本 crate 启用的解码 feature 识别格式；
/// Cargo.toml 只启了 `png`，故实际仅支持 PNG。
pub fn decode_qr_bytes(bytes: &[u8]) -> Result<String, String> {
    let img = image::load_from_memory(bytes)
        .map_err(|e| format!("无法解码图片（仅支持 PNG）：{e:#}"))?;
    decode_qr_image(&img)
}

/// `DynamicImage` → 二维码文本（与 [`decode_qr_bytes`] 分离，测试可直喂图）。
///
/// 用 `prepare_from_greyscale`（像素回调）而不是 `PreparedImage::prepare`：
/// 后者参数类型是 rqrr 内部依赖的 `image` crate 的 `GrayImage`，与本 crate
/// 的 `image` 版本若不一致会编译不过；回调签名不受版本耦合影响。
pub fn decode_qr_image(img: &image::DynamicImage) -> Result<String, String> {
    let luma = img.to_luma8();
    let (w, h) = luma.dimensions();
    let mut prepared = rqrr::PreparedImage::prepare_from_greyscale(
        w as usize,
        h as usize,
        |x: usize, y: usize| luma.get_pixel(x as u32, y as u32)[0],
    );
    let grids = prepared.detect_grids();
    let Some(grid) = grids.into_iter().next() else {
        return Err("未能从图片识别二维码".to_owned());
    };
    let (_, text) = grid
        .decode()
        .map_err(|e| format!("二维码内容解码失败：{e}"))?;
    Ok(text)
}
