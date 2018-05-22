---
layout: post
title: K8S-Technique
categories: [Mastered]
tags: Mastered
---



## Security

#### Security Policy

1. policy是需要授权的，然后user或者目标pod的ServiceAccount才能使用。大部分pod不是user创建的，而是由ControllerManager创建的（Deployment、ReplicaSet），所以如果授权Controller可以访问策略，那么基本上Controller就可以访问所有pod了。所以，**一般是授权给pod的Service Account**
2. RBAC是标准k8s授权模式
3. ​

#### Security Tips and Practices

[references](https://medium.com/containerum/top-security-tips-for-your-kubernetes-cluster-9b23a4e95111)

1. Reduce network exposure ？
2. 资源隔离(pod之间):  网络策略+资源Requests和Limits
3. 有效的access management：
   1. RBAC
   2. rotate your credentials regularly ？
4. 限制容器的特权：
   1.  采用方案 [Pod Security Policy](https://kubernetes.io/docs/concepts/policy/pod-security-policy/)
      1. 以non-root用户运行容器
      2. 以non-privileged运行容器
      3. selinux等等都可以在这里面做
5. Use images from known sources
6. 监控logs（应用的+cluster的） + 定期执行审计
   1. 日志：
      1. ELK stack (ElasticSearch, Logstash and Kibana) 优选
      2. Datadog：免费，如果只有5个node左右，推荐
      3. Amazon Cloudwatch
   2. 审计：
      1. Clair：CoreOS的扫描脆弱性的
      2. Kube-bench：Aquasec的用于检查k8s是否安全部署
      3. OpenSCAP