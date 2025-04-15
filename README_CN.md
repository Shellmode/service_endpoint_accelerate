# AWS 服务端点加速解决方案

本项目提供了一种利用 AWS 骨干网络加速跨区域 AWS 服务端点的解决方案。它通过 VPC 对等连接和网络负载均衡器（NLB）建立了位于 AWS 外部的客户端与不同区域的 AWS 服务端点之间的连接。

## 概述

当 AWS 外部的客户端需要访问远距离区域的 AWS 服务时，网络延迟会显著影响性能。本解决方案通过以下方式解决这一挑战：

1. 在服务端点所在区域（如雅加达）创建 VPC
2. 为目标服务（如 SageMaker）设置 VPC 端点
3. 在靠近客户端的区域（如新加坡）创建另一个 VPC
4. 建立两个 VPC 之间的对等连接
5. 在靠近客户端的区域部署面向互联网的 NLB
6. 配置路由以通过 AWS 骨干网络引导流量

## 架构

```
客户端（新加坡，非 AWS）→ NLB（ap-southeast-1）→ VPC 对等连接 → VPC 端点 → SageMaker（ap-southeast-3）
```

### 组件：

- **资源 VPC**：在服务端点区域（ap-southeast-3/雅加达）创建
- **资源 VPC 端点**：目标 AWS 服务的接口端点
- **暴露 VPC**：在靠近客户端的区域（ap-southeast-1/新加坡）创建
- **VPC 对等连接**：连接资源 VPC 和暴露 VPC
- **网络负载均衡器**：部署在暴露 VPC 中，可从互联网访问

## 使用场景

本演示展示了位于新加坡非 AWS 服务器的客户端访问雅加达（ap-southeast-3）的 SageMaker 端点的加速方案。

## 前提条件

- 配置了适当权限的 AWS CLI
- Bash shell 环境

## 部署

1. 在 `env.template` 中配置参数：
   ```
   RESOURCE_REGION="ap-southeast-3"  # 服务端点所在区域，需要加速
   RESOURCE_VPC_NAME="sagemaker-resource-vpc"  # 资源区域的 VPC 名称
   RESOURCE_SERVICE_NAME="com.amazonaws.$RESOURCE_REGION.sagemaker.runtime"  # 需要加速的服务端点
   RESOURCE_VPC_ENDPOINT_NAME="sagemaker-vpc-endpoint"  # VPC 端点名称
   EXPOSE_REGION="ap-southeast-1"  # 客户端所在区域
   EXPOSE_VPC_NAME="sagemaker-expose-vpc"  # 暴露区域的 VPC 名称
   ```

2. 运行部署脚本：
   ```bash
   ./deploy_all.sh
   ```

3. 部署过程将：
   - 创建所有必要的资源
   - 配置网络和安全设置
   - 将资源 ID 保存到 `env` 文件
   - 输出用于客户端访问的 NLB DNS 名称

## 清理

要删除所有创建的资源：

```bash
./cleanup.sh
```

此脚本将使用存储在 `env` 文件中的信息删除部署期间创建的所有资源。

## 部署流程

该解决方案通过按顺序执行一系列脚本进行部署：

1. `1.resource_vpc_deploy.sh`：在服务端点区域创建 VPC
2. `2.resource_endpoint_deploy.sh`：为目标服务设置 VPC 端点
3. `3.expose_vpc_deploy.sh`：在靠近客户端的区域创建 VPC
4. `4.vpc_peering.sh`：建立两个 VPC 之间的对等连接
5. `5.update_route_table.sh`：更新路由表以启用流量流动
6. `6.expose_nlb_deploy.sh`：在靠近客户端的区域部署 NLB

## 注意事项

- 此解决方案适用于客户端位于固定位置的场景
- 它利用 AWS 全球骨干网络提高性能
- 通过修改 `RESOURCE_SERVICE_NAME` 参数，该解决方案可以适用于不同的 AWS 服务
