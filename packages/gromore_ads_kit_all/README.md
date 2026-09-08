# gromore_ads_kit_all

`gromore_ads_kit` 的第三方 ADN 全家桶。需要优量汇、百度、Sigmob 和快手时，只添加这一项：

```yaml
dependencies:
  gromore_ads_kit_all: ^2.0.0
```

如果只需要其中一部分，请直接依赖核心包和对应扩展包，以减少包体积与隐私合规范围。

本包不包含官方广告测试工具；调试时请另外临时添加 `gromore_ads_kit_debug_tools`。
