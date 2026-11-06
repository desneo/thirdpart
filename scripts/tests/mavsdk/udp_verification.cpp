#include <mavsdk/mavsdk.hpp>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <unistd.h>
#include <poll.h>
#include <array>
#include <chrono>
#include <cstdint>
#include <cerrno>
#include <functional>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <thread>

using namespace std::chrono_literals;

// 检查不依赖 assert，Release 构建中也始终执行。
void require(bool condition, const std::string& message)
{
    if (!condition) throw std::runtime_error(message);
}

struct Socket {
    int fd = ::socket(AF_INET, SOCK_DGRAM, 0);
    Socket() { require(fd >= 0, "创建 UDP socket 失败"); }
    ~Socket() { if (fd >= 0) ::close(fd); }
    Socket(const Socket&) = delete;
    Socket& operator=(const Socket&) = delete;
};

sockaddr_in address(const char* ip, uint16_t port)
{
    sockaddr_in addr{};
    addr.sin_family = AF_INET;
    addr.sin_port = htons(port);
    require(inet_pton(AF_INET, ip, &addr.sin_addr) == 1, "IPv4 地址无效");
    return addr;
}

bool bind_socket(Socket& sock, const char* ip, uint16_t port)
{
    auto addr = address(ip, port);
    return ::bind(sock.fd, reinterpret_cast<sockaddr*>(&addr), sizeof(addr)) == 0;
}

uint16_t available_port(bool offset)
{
    for (uint16_t port = 35000; port < 55000; port += 137) {
        Socket first;
        Socket second;
        if (bind_socket(first, "0.0.0.0", port) &&
            (!offset || bind_socket(second, "0.0.0.0", port + 100))) return port;
    }
    throw std::runtime_error("没有可用的测试 UDP 端口");
}

void require_bound(const char* ip, uint16_t port)
{
    Socket probe;
    require(!bind_socket(probe, ip, port) && errno == EADDRINUSE,
            "预期端口未被监听: " + std::string(ip) + ":" + std::to_string(port));
}

// MAVLink v1 HEARTBEAT，sysid=42、compid=1、ArduPilot quadrotor。
// 使用标准 X.25 CRC 和 HEARTBEAT CRC_EXTRA=50，无需依赖未安装的 MAVLink C 头文件。
std::array<uint8_t, 17> heartbeat(uint8_t sequence)
{
    std::array<uint8_t, 17> frame{0xfe, 9, sequence, 42, 1, 0,
        0, 0, 0, 0, 2, 3, 0, 4, 3, 0, 0};
    uint16_t crc = 0xffff;
    auto accumulate = [&crc](uint8_t byte) {
        uint8_t tmp = byte ^ (crc & 0xff);
        tmp ^= static_cast<uint8_t>(tmp << 4);
        crc = (crc >> 8) ^ (static_cast<uint16_t>(tmp) << 8) ^
              (static_cast<uint16_t>(tmp) << 3) ^ (tmp >> 4);
    };
    for (size_t i = 1; i < 15; ++i) accumulate(frame[i]);
    accumulate(50);
    frame[15] = crc & 0xff;
    frame[16] = crc >> 8;
    return frame;
}

void send_heartbeat(Socket& sock, uint16_t port, uint8_t seq)
{
    const auto packet = heartbeat(seq);
    auto dest = address("127.0.0.1", port);
    require(sendto(sock.fd, packet.data(), packet.size(), 0,
                   reinterpret_cast<sockaddr*>(&dest), sizeof(dest)) ==
                static_cast<ssize_t>(packet.size()), "发送模拟 heartbeat 失败");
}

bool wait_until(const std::function<bool()>& predicate, std::chrono::milliseconds timeout,
                const std::function<void()>& tick = [] {})
{
    const auto end = std::chrono::steady_clock::now() + timeout;
    while (std::chrono::steady_clock::now() < end) {
        if (predicate()) return true;
        tick();
        std::this_thread::sleep_for(100ms);
    }
    return predicate();
}

void input_test(const std::string& url, uint16_t input_port, uint16_t actual_port, bool reconnect)
{
    mavsdk::Mavsdk sdk{mavsdk::Mavsdk::Configuration{mavsdk::ComponentType::GroundStation}};
    sdk.set_heartbeat_timeout_s(1.0);
    if (reconnect) {
        const auto version = sdk.version();
        require(version.find("v4.1.0") != std::string::npos &&
                version.find("dirty") != std::string::npos, "版本缺少 v4.1.0 或 dirty 标识: " + version);
        std::cout << "归档版本: " << version << '\n';
    }
    Socket sender;
    uint8_t seq = 0;
    auto [result, handle] = sdk.add_any_connection_with_handle(url);
    require(result == mavsdk::ConnectionResult::Success, "添加输入连接失败: " + url);
    require_bound("127.0.0.1", actual_port);
    // 输入 URL 的原端口应保持空闲，不能误将补丁实现为双端口监听。
    { Socket probe; require(bind_socket(probe, "127.0.0.1", input_port), "URL 原端口被意外占用"); }
    auto tick = [&] { send_heartbeat(sender, actual_port, seq++); };
    require(wait_until([&] { return !sdk.systems().empty() && sdk.systems().front()->is_connected(); },
                       8s, tick), "没有发现模拟设备: " + url);
    auto system = sdk.systems().front();
    require(system->get_system_id() == 42, "设备 system_id 错误");
    if (reconnect) {
        require(wait_until([&] { return !system->is_connected(); }, 5s), "停止 heartbeat 后没有断开");
        require(wait_until([&] { return system->is_connected(); }, 5s, tick), "恢复 heartbeat 后未重连");
        require(sdk.systems().size() == 1 && sdk.systems().front() == system,
                "重连创建了重复设备，或改变了设备对象");
    }
    sdk.remove_connection(handle);
    { Socket probe; require(bind_socket(probe, "127.0.0.1", actual_port), "移除连接未释放端口"); }
    auto [again, new_handle] = sdk.add_any_connection_with_handle(url);
    require(again == mavsdk::ConnectionResult::Success, "连接移除后无法重建");
    require_bound("127.0.0.1", actual_port);
    // 必须先等旧设备超时，才能证明新的连接真正收到了 heartbeat。
    require(wait_until([&] { return !system->is_connected(); }, 5s), "重建连接前设备未超时");
    require(wait_until([&] { return system->is_connected(); }, 5s, tick), "重建连接后 heartbeat 未恢复");
    sdk.remove_connection(new_handle);
    std::cout << "通过: " << url << " -> 本地 " << actual_port
              << (reconnect ? "；发现/断流/同设备重连/连接重建" : "；发现/连接重建") << '\n';
}

void output_test(const std::string& scheme)
{
    const auto port = available_port(false);
    // 特定 loopback 地址优先接收远端数据；双方 reuse_address 允许 SDK 绑定 wildcard:P。
    // 本地源地址是 127.0.0.1，远端是 127.0.0.2，避免单机自收和端口冲突。
    Socket receiver;
    int reuse = 1;
    require(setsockopt(receiver.fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse)) == 0,
            "设置远端 SO_REUSEADDR 失败");
    require(bind_socket(receiver, "127.0.0.2", port), "绑定模拟远端失败");
    mavsdk::Mavsdk::Configuration config{mavsdk::ComponentType::GroundStation};
    config.set_always_send_heartbeats(true);
    mavsdk::Mavsdk sdk{config};
    const auto url = scheme + "://127.0.0.2:" + std::to_string(port);
    auto [result, handle] = sdk.add_any_connection_with_handle(url);
    require(result == mavsdk::ConnectionResult::Success, "添加输出连接失败: " + url);
    require_bound("127.0.0.3", port); // 验证 wildcard bind，不只绑定远端或主 loopback 地址。
    pollfd pending{receiver.fd, POLLIN, 0};
    require(poll(&pending, 1, 5000) > 0 && (pending.revents & POLLIN), "远端未收到 MAVSDK 数据");
    std::array<uint8_t, 2048> buffer{};
    sockaddr_in source{};
    socklen_t length = sizeof(source);
    require(recvfrom(receiver.fd, buffer.data(), buffer.size(), 0,
                     reinterpret_cast<sockaddr*>(&source), &length) > 0, "读取远端数据失败");
    require(ntohs(source.sin_port) == port, "输出源端口不等于 URL 端口");
    require(source.sin_addr.s_addr == htonl(INADDR_LOOPBACK), "数据不是来自独立的本地 loopback 地址");
    sdk.remove_connection(handle);
    std::cout << "通过: " << url << "；本地 wildcard 绑定和源端口 " << port << '\n';
}

int main()
{
    try {
        const auto port = available_port(true);
        input_test("udpin://127.0.0.1:" + std::to_string(port), port, port + 100, true);
        input_test("udp://:" + std::to_string(port), port, port + 100, false);
        input_test("udp://0.0.0.0:" + std::to_string(port), port, port + 100, false);
        input_test("udpin://127.0.0.1:65435", 65435, 65535, false);
        output_test("udpout");
        output_test("udp");
        std::cout << "MAVSDK UDP 定制验证通过：6 个场景\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << "MAVSDK UDP 验证失败：" << error.what() << '\n';
        return 1;
    }
}
