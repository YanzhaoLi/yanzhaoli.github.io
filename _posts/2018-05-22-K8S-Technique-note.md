---
layout: post
title: K8S-Technique
categories: [Mastered]
tags: Mastered
---



## Install 

如何检查系统是否满足安装需求

systemd日志放在哪？systemd运行的kubelet的日志放在哪？首先直接执行看kubelet有啥输出

直接关闭kubelet进程会有啥结果？master看不到后，就会把该kubelet的pod状态标记为unknown？

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



### 暴露给cluster外访问

**Pod**方式

+ hostnetwork：true 直接使用**所在node**主机网络，可看到所有网络接口，可以用作flannel来管理主机网络
+ hostport：xxx   完成容器到**所在node的**host端口映射，可以用作nginx ingress controller中的pod，将外部traffic都流向主机的443和80端口

**Service**方式

+ NodePort：服务端口映射到**每一台Node**主机端口映射

**Ingress**方式

+ 一个controller（比如Deployment)，这是一组pod（一般是nginx/HAproxy）, 使用hostport映射到主机端口
+ 一个ingress对象，里面定义需要域名->服务的映射，由controller中的nginx等来使用。



### configMap

无法修改已经注入到pod中的env

```k8s
envFrom:
- configMapRef:
  name: configmap-name
```

可以实时修改volumes里面的值, 通过更新configmap

```
volumesMounts:
- name: volumes-name
  mountPath: path
Volumes：
- name： volumes-name
  configMap:
    key:data
```



#### PodPreset

+ 你不想一个个更改pod的Template，那么创建一个带Selector的podPreset，在请求pod创建时就会自动调用podpreset对相应Template进行修改
+ pod的spec中可以添加annotation，明确不让任何podPreset修改该pod的启动模板



#### Aggregated API Server

将原来的API Server拆开，方便用户加入自己的API Server。

用户可以自定义资源类型，为了管理该类型，还会自定义该类型的controller



### [understanding cui - Jon Langemak](http://www.dasblinkenlichten.com/understanding-cni-container-networking-interface/)

+ 首先container runtime先创建一个网络命名空间`ip netns add NAME`
+ 然后准备环境变量: plugin路径、使用的命令，哪个容器（就是netns）等
+ 配置文件中指定使用什么插件如bridge， 以stdin的方式给插件
+ `env-setting    plugin_executable   <   xx.conf` 







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