# 应用信息规格

**状态**: 生效中
**依赖**: 无
**相关测试**: `test/feature/features/settings_feature_test.dart`

---

## 概述

本规格定义应用版本信息与开源库清单的业务规则。应用信息需提供版本号、构建号与发布日期；开源库清单按 Flutter 与 Rust 分组，包含全部直接依赖（含开发依赖）。

---

## GIVEN-WHEN-THEN 场景

### 场景：查看应用版本信息

- **GIVEN**: 应用已构建并具备版本元数据
- **WHEN**: 调用方请求应用信息
- **THEN**: 系统返回版本号、构建号与发布日期

### 场景：查看开源库清单

- **GIVEN**: 应用依赖清单可用
- **WHEN**: 调用方请求开源库清单
- **THEN**: 系统返回 Flutter 与 Rust 两类清单
- **AND**: 清单包含运行时依赖与开发依赖

---

## 开源库清单（直接依赖）

### Flutter（运行时）

- flutter (sdk)
- cupertino_icons ^1.0.8
- flutter_rust_bridge ^2.11.0
- ffi ^2.1.0
- provider ^6.1.0
- rxdart ^0.28.0
- flutter_markdown ^0.7.0
- freezed_annotation ^2.4.0
- path_provider ^2.1.0
- shared_preferences ^2.2.0
- package_info_plus ^8.0.0
- fluttertoast ^8.2.8
- qr_flutter ^4.1.0
- image ^4.1.0
- mobile_scanner ^5.2.3
- file_picker ^8.0.0
- desktop_drop ^0.4.4
- zxing_lib ^1.1.4
- permission_handler ^11.3.1
- url_launcher ^6.3.2

### Flutter（开发/测试）

- flutter_test (sdk)
- flutter_lints ^6.0.0
- build_runner ^2.4.0
- freezed ^2.5.0
- json_serializable ^6.8.0
- qr ^3.0.2

### Rust（运行时）

- flutter_rust_bridge =2.11.1
- loro =1.3.1
- rusqlite =0.33.0
- uuid =1.11.0
- serde =1.0
- serde_json =1.0
- base64 =0.22
- thiserror =2.0
- anyhow =1.0
- chrono =0.4
- tracing =0.1
- tracing-subscriber =0.3
- bcrypt =0.16
- hkdf =0.12
- sha2 =0.10
- hex =0.4
- keyring =3.6
- libp2p =0.54
- futures =0.3
- tokio =1.0
- tokio-stream =0.1
- zeroize =1.7

### Rust（开发/测试）

- tempfile =3.8
- serial_test =3.2
