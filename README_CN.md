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

最终部署完成会输出用于客户端访问的 NLB DNS 名称

```bash
===== Deployment completed successfully =====
Thu Apr 17 11:47:44 CST 2025: All scripts have been executed
NLB URL: https://service-peering-nlb-1234567890.elb.ap-southeast-1.amazonaws.com
```

## 部署流程

该解决方案通过按顺序执行一系列脚本进行部署：

1. `1.resource_vpc_deploy.sh`：在服务端点区域创建 VPC
2. `2.resource_endpoint_deploy.sh`：为目标服务设置 VPC 端点
3. `3.expose_vpc_deploy.sh`：在靠近客户端的区域创建 VPC
4. `4.vpc_peering.sh`：建立两个 VPC 之间的对等连接
5. `5.update_route_table.sh`：更新路由表以启用流量流动
6. `6.expose_nlb_deploy.sh`：在靠近客户端的区域部署 NLB

## 代码中如何使用部署的 NLB 进行加速

### Option1: 修改 endpoint_url，跳过 TLS 证书验证

原理：

* SDK 访问 NLB 的地址，作为 service 的 endpoint
* 需要跳过 TLS 证书校验，因为 NLB 只做网络转发，但是 SDK 访问的 https 地址是 NLB，如果校验 TLS 证书则无法匹配

Python demo

```python
import urllib3
import boto3
urllib3.disable_warnings()

...
sm_client = boto3.client(
    'sagemaker-runtime',
    region_name="ap-southeast-3", # sagemaker endpoint 所在 region
    endpoint_url="https://service-peering-nlb-1234567890.elb.ap-southeast-1.amazonaws.com", # 加速 NLB URL
    verify = False # 不验证 TLS 证书
)
...
```

Golang demo

```go
http.DefaultTransport.(*http.Transport).TLSClientConfig = &tls.Config{InsecureSkipVerify: true}
// 创建 AWS 会话
sess := session.Must(session.NewSession(&aws.Config{
  Region:   aws.String("ap-southeast-3"),
  Endpoint: aws.String("https://service-peering-nlb-1234567890.elb.ap-southeast-1.amazonaws.com"),
}))

// 创建 SageMaker Runtime 客户端
sagemakerClient := sagemakerruntime.New(sess)
```

### Option2: 修改 host

直接在调用端修改原本 service endpoint 的 host 到 NLB 的 ip 即可（此时建议 NLB 绑定 EIP），例如

```bash
cat /etc/hosts

xx.xx.yy.yy runtime.sagemaker.ap-southeast-3.amazonaws.com
```

用这种方法在代码中不需要跳过 TLS 证书校验



## 清理

要删除所有创建的资源：

```bash
./cleanup.sh
```

此脚本将使用存储在 `env` 文件中的信息删除部署期间创建的所有资源。



## 注意事项

- 此解决方案适用于客户端位于固定位置的场景
- 它利用 AWS 全球骨干网络提高性能
- 通过修改 `RESOURCE_SERVICE_NAME` 参数，该解决方案可以适用于不同的 AWS 服务
