## Clash 控制器的使用说明

Clash Dash 可调用遵循 [Clash RESTful API](https://wiki.metacubex.one/api/) 的后端，请先确保后端正常运行后再使用该 App。

<img src="notice.png" alt="Clash Dash Notice" width="300">

其他类似于 Clash Dash 的项目：
- [metacubexd](https://github.com/MetaCubeX/metacubexd)
- [zashboard](https://github.com/Zephyruso/zashboard)
- [yacd](https://github.com/haishanh/yacd)
### 添加 Clash 控制器：
 - [OpenClash](https://github.com/vernesong/OpenClash)：控制面板登录信息从 OpenClash 的运行状态处获取（你也可以使用 OpenWRT 方式添加，获取更多操作，具体添加方式请在 Clash Dash 中查看使用帮助）
- [MihomoTProxy](https://github.com/morytyann/OpenWrt-mihomo/wiki)：控制面板登录信息从插件的“混入配置” - “混入选项” - “外部控制配置” 处获取。
- [Docker](https://hub.docker.com/r/metacubex/mihomo)：控制面板登录信息从配置文件中获取。
- [sing-box](https://github.com/SagerNet/sing-box)：控制面板登录信息从配置文件中获取。
 
### 添加控制器后的使用说明：
可对已添加的控制器可调出菜单，对该控制器的信息进行删除或编辑操作，以及：
- 设为快速启用：对设为快速启用的控制器，在冷启动打开 Clash Dash 的时候会直接进入该控制器的概览界面。
- 切换代理模式：可对选中的控制器快速切换直连、规则或全局的代理模式。
- 订阅管理（使用 OpenWRT 登录方式可用）：调用 OpenClash 添加订阅地址、启用或禁用以及筛选节点等功能。
- 切换配置（使用 OpenWRT 登录方式可用）：调用 OpenClash 切换配置、删除或编辑配置文件。
- 附加规则（使用 OpenWRT 登录方式可用）：调用 OpenClash 添加自定义规则。
- 重启服务（使用 OpenWRT 登录方式可用）：调用 OpenClash 重启内核。

点击已添加的控制器可进入该控制器的主界面，其中包括：
- 概览页面：显示实时流量、连接数以及内存使用信息（某些内核后端无内存使用信息）。
- 代理页面：可查看代理组信息，以及切换其所使用的代理节点。
- 规则页面：查看配置文件中的规则设定，更新规则提供者（rule-provider）。
- 连接页面：实时看看活动连接，点击可查看连接详情。点击右下角的 “...”图标可调出更多菜单。
- 更多（More） 页面：对后端进行配置，查看内核日志以及调用内核进行 DNS 解析查询。

### 其他说明
如有任何问题，你可使用 [GitHub issue](https://github.com/bin64/Clash-Dash/issues) 或 [Telegram 群组](https://t.me/Clash_Dash_iOS) 寻求帮助 （请先阅读 [提问的智慧](https://github.com/ryanhanwu/How-To-Ask-Questions-The-Smart-Way/blob/main/README-zh_CN.md) ）。
