//! 配对二维码 encode→PNG→decode 往返测试（QR 图片保存/识别任务验收标准 2）。
//!
//! 覆盖 `cardmind_backend::qr` 的核心逻辑：`render_credential_qr_png` 纯函数 +
//! `decode_qr_bytes`/`decode_qr_image` 解码。`save_pairing_qr_png` /
//! `decode_pairing_qr_file` 的 rfd 系统对话框路径在 headless 环境下不实弹，
//! 靠本文件的往返测试覆盖「渲染出的 PNG 确实能被识别回原凭证」这一核心。

use cardmind_backend::qr::{decode_qr_bytes, render_credential_qr_png};

/// `cm1.` 形式的样例凭证（结构与真凭证一致：`cm1.` + base64url 载荷）。
const SAMPLE_CREDENTIAL: &str =
    "cm1.AQIDBAUGBwgJCgsMDQ4PEBESExQVFhcYGRobHB0eHyAhIiMkJSYnKCkqKywtLi8w";

/// 验收标准 2：`cm1.` 凭证 → 二维码 PNG → 图片解码回文本，逐字相同。
#[test]
fn credential_qr_png_roundtrip() {
    let png = render_credential_qr_png(SAMPLE_CREDENTIAL).expect("render_credential_qr_png 应成功");

    // PNG 魔数 sanity check。
    assert_eq!(&png[..8], b"\x89PNG\r\n\x1a\n", "输出应为 PNG 字节流");

    let decoded = decode_qr_bytes(&png).expect("生成的二维码 PNG 应可被识别");
    assert_eq!(decoded, SAMPLE_CREDENTIAL, "解码文本应与原凭证逐字相同");
}

/// 真实凭证长度的往返（v2 凭证含内嵌 IP，比样例长——验证 QR 容量足够）。
#[test]
fn long_credential_qr_png_roundtrip() {
    // v2 凭证含若干 "ip:port" 内嵌地址，串明显更长。
    let long = format!(
        "{SAMPLE_CREDENTIAL}{}",
        "MTkyLjE2OC4xLjI6MTIzNDU,".repeat(4)
    );
    assert!(long.starts_with("cm1."));
    let png = render_credential_qr_png(&long).expect("长凭证渲染应成功");
    let decoded = decode_qr_bytes(&png).expect("长凭证二维码 PNG 应可被识别");
    assert_eq!(decoded, long, "长凭证解码文本应逐字相同");
}

/// 负向用例：非二维码图片 → 解码报错（不是 panic、不是 Ok）。
#[test]
fn non_qr_image_decode_errors() {
    // 生成一张纯色 PNG（无任何二维码图案）。
    let img = image::DynamicImage::ImageLuma8(image::GrayImage::from_pixel(
        256,
        256,
        image::Luma([200u8]),
    ));
    let mut png = std::io::Cursor::new(Vec::new());
    img.write_to(&mut png, image::ImageFormat::Png).unwrap();

    let err = decode_qr_bytes(&png.into_inner()).expect_err("纯色图不应识别出二维码");
    assert!(
        err.contains("未能从图片识别二维码") || err.contains("解码失败"),
        "错误信息应可读，实际：{err}"
    );
}

/// 负向用例：根本不可解码的字节流 → 图片解码报错。
#[test]
fn non_image_bytes_decode_errors() {
    let err = decode_qr_bytes(b"this is not an image").expect_err("非图片字节不应识别出二维码");
    assert!(
        err.contains("无法解码图片"),
        "应先报图片解码错误，实际：{err}"
    );
}
