---
layout: post
title: K8S-Technique
categories: [Mastered]
tags: Mastered
---



## Install 

如何检查系统是否满足安装需求

systemd日志放在哪？systemd运行的kubelet的日志放在哪？首先直接执行看kubelet有啥输出

直接关闭kubelet进程会有啥结果？

如何apt-get只下载deb包不安装，如何测试deb的安装结果？参见shell technique

kubeadm init --kubernetes-version=v1.8.8





问题：kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10255/healthz' failed with error: Get http://localhost:10255/healthz: dial tcp 127.0.0.1:10255: getsockopt: connection refused.

解决：Environment="KUBELET_SYSTEM_PODS_ARGS=--pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true **--fail-swap-on=false**" 

​	systemctl daemon-reload

问题：Will mark node ubuntu as master by adding a label and a taint 卡死在这里

解决：换了 docker.io  + 安装了kubernetes-cni（kubelet依赖) + 换了原装的kubelet和kubeadm配置

 

### ubuntu16.04 下kubeadm安装

+ 关闭swapoff -a； iptables -F；
+ 按照官网方法安装docker.io 和 kubelet(自动关联kubernetes-cni包)；
+ kubelet参数中的fs驱动改成和docker info中的驱动一样，cgroupfs
+ 提前准备好下载不下来的image
  + 
+ kubeadm init --kubernetes-version=v1.10.3 --pod --pod-network-cidr=10.244.0.0/16
+ 另一个node join加入，此时发现node NotReady
+ `kubectl apply -f https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml` 此时node ready

#### 如何在etcd中找到kubernetes的keys

k8s使用的是3.0版本的etcd，于是首先 `export ETCDCTL_API=3`

然后```etcdctl get / --prefix --keys-only```

### #kubeadm是如何设置权限的呢

flannel kube-proxy 等用到的参数不少都是通过configmap挂载过去的data

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





![kubernetes-pod-cheatsheet.png](./kubernetes-pod-cheatsheet.png)