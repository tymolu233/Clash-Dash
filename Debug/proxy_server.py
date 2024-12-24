"""
测试脚本：OpenWRT OpenClash 状态获取问题复现

此脚本用于模拟和调试 OpenWRT 管理界面无法正常获取 OpenClash 状态的问题：
- 创建一个代理服务器，监听 8091 端口
- 拦截所有发往 /cgi-bin/luci/admin/services/openclash/status 的请求，返回 403 错误
- 其他请求则转发至目标 OpenWRT 设备（192.168.110.45:80）
- 完整记录请求和响应的详细信息，便于问题分析

使用方法：
1. 运行此代理服务器
2. 将浏览器代理设置指向 代理服务器 IP:8091
3. 访问 OpenWRT 管理界面，观察 OpenClash 状态获取失败的情况

作用：
- 验证 commit ID c408bd58e3752a990056a80030badf453889cf4e 是否可用
"""

import http.server
import socketserver
import requests
from urllib.parse import urlparse

# 配置
TARGET_HOST = "192.168.110.45"
TARGET_PORT = "80"
PROXY_PORT = 8091


class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    def do_GET(self):
        print(f"\n[Request] GET {self.path}")
        print("[Request Headers]")
        for header, value in self.headers.items():
            print(f"{header}: {value}")

        # startswith 来检查路径前缀，模拟 403 返回
        if self.path.startswith("/cgi-bin/luci/admin/services/openclash/status"):
            print("\n[Response] 403 Forbidden")
            self.send_response(403)
            self.send_header('Content-type', 'text/plain')
            self.send_header('Content-Length', '9')
            self.end_headers()
            self.wfile.write(b"Forbidden")
            return

        target_url = f"http://{TARGET_HOST}:{TARGET_PORT}{self.path}"
        print(f"\n[Forward] {target_url}")
        try:
            headers = {key: val for key, val in self.headers.items()}
            response = requests.get(target_url, headers=headers, stream=True)

            print(f"\n[Response] {response.status_code}")
            print("[Response Headers]")
            for header, value in response.headers.items():
                print(f"{header}: {value}")

            self.send_response(response.status_code)
            for header, value in response.headers.items():
                if header.lower() not in ['transfer-encoding', 'content-encoding', 'content-length']:
                    self.send_header(header, value)

            content = response.content
            if content:
                self.send_header('Content-Length', len(content))

            self.end_headers()

            if content:
                print("\n[Response Content]")
                print(content.decode('utf-8', errors='ignore'))
                self.wfile.write(content)

        except Exception as e:
            print(f"\n[Error] {str(e)}")
            self.send_error(500, str(e))

    def do_POST(self):
        print(f"\n[Request] POST {self.path}")
        print("[Request Headers]")
        for header, value in self.headers.items():
            print(f"{header}: {value}")

        if self.path.startswith("/cgi-bin/luci/admin/services/openclash/status"):
            print("\n[Response] 403 Forbidden")
            self.send_response(403)
            self.send_header('Content-type', 'text/plain')
            self.send_header('Content-Length', '9')
            self.end_headers()
            self.wfile.write(b"Forbidden")
            return

        content_length = int(self.headers.get('Content-Length', 0))
        post_data = self.rfile.read(content_length)
        print("\n[Request Body]")
        print(post_data.decode('utf-8', errors='ignore'))

        target_url = f"http://{TARGET_HOST}:{TARGET_PORT}{self.path}"
        print(f"\n[Forward] {target_url}")
        try:
            headers = {key: val for key, val in self.headers.items()}
            response = requests.post(target_url, headers=headers, data=post_data, stream=True)

            print(f"\n[Response] {response.status_code}")
            print("[Response Headers]")
            for header, value in response.headers.items():
                print(f"{header}: {value}")

            self.send_response(response.status_code)
            for header, value in response.headers.items():
                if header.lower() not in ['transfer-encoding', 'content-encoding', 'content-length']:
                    self.send_header(header, value)

            content = response.content
            if content:
                self.send_header('Content-Length', len(content))

            self.end_headers()

            if content:
                print("\n[Response Content]")
                print(content.decode('utf-8', errors='ignore'))
                self.wfile.write(content)

        except Exception as e:
            print(f"\n[Error] {str(e)}")
            self.send_error(500, str(e))


def run_proxy_server():
    handler = ProxyHandler
    with socketserver.TCPServer(("", PROXY_PORT), handler) as httpd:
        print(f"Proxy server running on port {PROXY_PORT}")
        httpd.serve_forever()


if __name__ == "__main__":
    run_proxy_server()