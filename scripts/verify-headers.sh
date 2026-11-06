#!/usr/bin/env bash
# 在当前系统编译并运行通用头文件库的最小使用示例。
set -euo pipefail
repo_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
cat > "$test_dir/headers.cpp" <<'CPP'
#include <Eigen/Dense>
#include <eventpp/eventdispatcher.h>
#include <magic_enum/magic_enum.hpp>
#include <nlohmann/json.hpp>
#include <cassert>
#include <iostream>

enum class State { Ready, Done };

int main() {
    Eigen::Matrix2d matrix;
    matrix << 2, 0, 0, 3;
    assert(matrix.determinant() == 6);
    eventpp::EventDispatcher<int, void(int)> dispatcher;
    int received = 0;
    dispatcher.appendListener(1, [&](int value) { received = value; });
    dispatcher.dispatch(1, 42);
    assert(received == 42);
    assert(magic_enum::enum_name(State::Ready) == "Ready");
    auto document = nlohmann::json::parse(R"({"value":42})");
    assert(document.at("value").get<int>() == 42);
    assert(nlohmann::json::parse(document.dump()) == document);
    std::cout << "Eigen、eventpp、magic_enum、nlohmann_json 编译和运行通过\n";
}
CPP
"${CXX:-g++}" -std=c++17 -O2 -Wall -Wextra -pedantic \
    -I"$repo_dir/eigen/5.0.1" \
    -I"$repo_dir/eventcpp/v0.1.3/include" \
    -I"$repo_dir/magic_enum/v0.9.8/include" \
    -I"$repo_dir/nlohmann_json/v3.12.0/include" \
    "$test_dir/headers.cpp" -o "$test_dir/headers"
"$test_dir/headers"
