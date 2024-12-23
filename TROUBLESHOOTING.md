# Clash Dash 故障排除指南

## OpenWRT 认证相关问题

### 问题描述
使用 OpenWRT 方式登录时可能遇到以下错误：
- 认证失败：`{"id":1,"result":null,"error":null}`
- "认证令牌已过期"

### 诊断步骤

1. 运行诊断脚本：
   ```bash
   curl -O https://raw.githubusercontent.com/bin64/Clash-Dash/refs/heads/main/Debug/get_openclash_status.sh && chmod +x get_openclash_status.sh && ./get_openclash_status.sh
   ```
   如果无法下载脚本，可以手动创建并运行。

2. 根据提示输入IP地址、端口、用户名、密码
3. 观察输出结果，判断问题所在

### 常见问题

1. 认证失败
   - 如果输出结果中包含 `{"id":1,"result":null,"error":null}`，则表示认证失败
   - 如果输出结果中包含 `认证令牌已过期`，则表示认证令牌已过期

2. 可能的原因及解决方案：
   - OpenWRT 的用户名和密码是否正确
   - OpenWRT 是否安装了 OpenClash 插件

3. 参考资料：
   - [OpenWRT JSON-RPC API 文档](https://github.com/openwrt/luci/wiki/JsonRpcHowTo)

4. 如果以上方法都无法解决问题，请在群组反馈：
   - Telegram 群组：https://t.me/Clash_Dash_iOS 
   - 反馈时请提供：
     - OpenWRT 版本
     - Clash Dash 版本
     - OpenClash 版本
     - 诊断脚本的返回结果

## OpenClash/MihomoTProxy 插件问题

### 问题描述
插件崩溃或无法正常运行

### 解决方案
1. 检查路由器内存使用情况：
   - 使用 `top` 命令查看内存使用情况
   - 如果内存不足，考虑清理不必要的进程或重启路由器

2. 内存不足的解决方案：
   - 关闭不必要的服务
   - 减少并发连接数
   - 考虑升级路由器内存

> **注意**：插件崩溃通常与 Clash Dash 无关，是路由器资源问题导致的。

这个 WIKI 提供了基本的故障排除步骤和解决方案。如果你觉得需要补充其他内容，请告诉我。