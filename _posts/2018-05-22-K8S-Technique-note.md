---
layout: post
title: K8S-Technique
categories: [Mastered]
tags: Mastered
---



## Cluster-api
![](./ClusterAPI-VsphereProvider.png)

## Install 

如何检查系统是否满足安装需求

systemd日志放在哪？systemd运行的kubelet的日志放在哪？首先直接执行看kubelet有啥输出

直接关闭kubelet进程会有啥结果？master看不到后，就会把该kubelet的pod状态标记为unknown？

问题：kubelet-check] The HTTP call equal to 'curl -sSL http://localhost:10255/healthz' failed with error: Get http://localhost:10255/healthz: dial tcp 127.0.0.1:10255: getsockopt: connection refused.

解决：Environment="KUBELET_SYSTEM_PODS_ARGS=--pod-manifest-path=/etc/kubernetes/manifests --allow-privileged=true **--fail-swap-on=false**" 

​	systemctl daemon-reload

问题：Will mark node ubuntu as master by adding a label and a taint 卡死在这里

解决：换了 docker.io  + 安装了kubernetes-cni（kubelet依赖) + 换了原装的kubelet和kubeadm配置

journalctl -xeu kubelet | grep -E CreatePodSandbox|kuberuntime_sandbox.go 检查是否有pulling image错误

 

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

k8s使用的是3.0版本的etcd，于是，

+ 首先 `export ETCDCTL_API=3`
+ 然后```etcdctl get / --prefix --keys-only```

#### kubeadm是如何设置权限的呢

flannel kube-proxy 等用到的参数不少都是通过configmap挂载过去的data

#### 如何使用audit2rbac来生成合适的RBAC策略

该项目灵感必然来源于selinux的策略生成方法    https://github.com/liggitt/audit2rbac



### 暴露给cluster外访问

**Pod**方式

+ hostnetwork：true 直接使用**所在node**主机网络，可看到所有网络接口，可以用作flannel来管理主机网络
+ hostport：xxx   完成容器到**所在node的**host端口映射，可以用作nginx ingress controller中的pod，将外部traffic都流向主机的443和80端口

**Service**方式

+ NodePort：服务端口映射到**每一台Node**主机端口映射
+ externalIP：首先，**设置一条路由**将该externalIP路由到某台node，然后该node上的iptables会将该其masqurade，然后从该node发起service访问，收到数据后再返回给访问发起者。为什么要DNAT而不直接转发给pod呢？因为不DNAT的话，目标pod会直接反馈给发起者，而发起者并没有给该pod发过请求，因此会直接忽略掉该packet

**Ingress**方式

+ 一个controller（比如Deployment)，这是一组pod（一般是nginx/HAproxy）, 使用hostport映射到主机端口(或者提供该controller的service，一般使用两个端口：一个用于转发；一个用于traffic展示)
+ 一个ingress对象，里面定义需要域名->服务的映射，由controller中的nginx等来使用。
+ 工作机制：执行负载均衡时，controller会直接把traffic转向具体的pod，而不是service，因为controller可以通过api请求某service对应的endpoints列表。



### ConfigMap

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



#### kubernetes nampespace

[转：如何利用k8s namespace来管理成千上完的资源](https://cloudplatform.googleblog.com/2018/04/Kubernetes-best-practices-Organizing-with-Namespaces.html)

default在大生产系统中不建议使用，最好创建几个ns，来管理服务们(参考一下flannel将各类资源放到不同ns)。并设置RBAC和ResourceQuotas

+ 创建：别怕创建ns，反而可能会提高性能，因为单个ns中资源减少了。 `kubectl create namespace test`，也可以添加标签。
+ 切换：使用ns可以通过指定ns名来完成，或者直接切换到某个ns，让你们组全在这个ns下工作。使用 [kubens](https://github.com/ahmetb/kubectx)  命令切换active ns。比如`kubens test`
+ 使用：跨ns访问service，只需要加上ns后缀即可`<Service Aame>.<NamespaceName>.svc.cluster.local` 实际使用只需要service.ns。**使用Network Policy也可以隔离ns**



#### 探针做健康检查

[Kubernetes best practices: Setting up health checks with readiness and liveness probes](https://cloudplatform.googleblog.com/2018/05/Kubernetes-best-practices-Setting-up-health-checks-with-readiness-and-liveness-probes.html)

两种探针类型：

+ Readiness: 准备好了，Service可以向其发traffic了。默认Service在pod启动完毕就会发流量，但有了探针，pod准备好之后才接收流量。
+ Liveness：还活着。默认一直发流量给pod，但是总该去查查它死了没，对吧。

三种探针方式：

+ http：最常用。你的容器包含一个lightweight httpserver，可以响应http请求
+ Command：你的容器有这么一个命令，执行它就知道自己是否健康
+ TCP：上面俩都不行了，就跟你的容器某端口建立一个TCP连接，成功了就健康，, a [gRPC](https://grpc.io/) or FTP service is a prime candidate for this type of probe 。

配置探针参数：

- `initialDelaySeconds`: 从*app启动*到*探针开始探测*的时间间隔。要设置好，不然app还没起来，探针就探测肯定跪，然后就永远不停的重启了。
- `periodSeconds`: 多长时间检查一次，默认10s
- `timeoutSeconds`: 发起探针请求后，多长时间没收到回复就标明跪了，timeout了，默认1s





### Understanding CNI - Jon Langemak

[Source](http://www.dasblinkenlichten.com/understanding-cni-container-networking-interface/)

首先，container runtime先创建一个网络命名空间`ip netns add NAME`

接着，调用插件，将该网络命名空间接入网络：

+ 准备环境变量: plugin路径、使用的命令，哪个容器（就是netns）等
+ 准备配置文件：指定使用什么插件如bridge， 以stdin的方式给插件
  + `env-setting    plugin_executable   <   xx.conf` 
+ 举例：
  + 创建一个网桥名为cbr0，然后创建一个pair连接到该网桥上
  + ipam分配ip地址（可以采用dhcp，也可以指定）给命名空间内的一端

*The CNI plugin is selected by passing Kubelet the –network-plugin=cni command-line option. Kubelet reads a file from –cni-conf-dir (default /etc/cni/net.d) and uses the CNI configuration from that file to set up each pod’s network. The CNI configuration file must match the CNI specification, and any required CNI plugins referenced by the configuration must be present in –cni-bin-dir (default /opt/cni/bin). If there are multiple CNI configuration files in the directory, the first one in lexicographic order of file name is used. In addition to the CNI plugin specified by the configuration file, Kubernetes requires the standard CNI lo plugin, at minimum version 0.2.0* 



### How Service Works

强烈推荐阅读这篇文章，[Sources](http://www.dasblinkenlichten.com/kubernetes-networking-101-services/), 讲述了如何抓包，如何知道veth的pair，iptables-save的解析。

**概述**：从pod中访问某service，首先给veth的pair接口，该接口把service ip重定向到对应的pod ip，采用的是DNAT的方式，该网络接口就会通过路由找到去某pod ip的下一跳。service ip是如何实现负载均衡到每一个pod ip呢？答案是iptables支持概率模式，即匹配某条的概率

**某ip对应的物理地址**，比如判断某网络是否会出容器

`arp $IP -nn`

**容器角度抓包分析**：

在container中找到veth的pair的index，然后在主机中找到那个@index的接口，比如veth75b33

`tcpdump -i veth75b33 -nn`  在该接口上的所有包，nn表示不将协议和端口转为名字：以数字形式显示

此时，可以看出目的地试service ip：service port；回来的包也是serviceip：serviceport

**主机角度抓包分析：**

`tcpdump -i ens32  -nn   host   $podip`  

表示在物理接口ens32上，抓取流向和留出  主机（host表示主机，net表示网络）$podip 的所有包，即src或dst是$podip的

此时，可以看出从$podip上发出的包的目的地已经被修正为destpodip:destpodport, 也就是在物理主机接口看来，是$podip 和 $destpodip之间在通信

**iptables-save 命令输出解析**

分析转发规则  <u>**只需要看NAT的prerouting 和 postrouting链**</u>

+ -A  PREROUTING -A append追加给该chain一条规则，若包成功匹配该条，则执行 -j 操作 
  + -p tcp    -d  $serviceip    -s [net/hostname/ip] -d [net/hostname/ip]
  + -i interface    -o interface    # 流入/流出该端口 的包
+ -j KUBESERVICE： 跳转到KUBE-SERVICE链继续执行
+ -j DNAT：  DNAT是一个链的终止target，修改该包的目的地址和端口；使用DNAT的话，返回的包自动NAT
  + `-j DNAT --to-destination 10.100.3.7:8080`
+ -m      *iptables可以使用扩展模块来进行数据包的匹配，语法就是 -m module_name*
  + `-m --comment`  注释
  + `-m sttistic  --mode random  --probability 0.3333329999982`    概率
  + `-m tcp   --dport $port`   使用 tcp 扩展模块的功能 (tcp扩展模块提供了 --dport, --tcp-flags, --sync等） 
+ -p tcp  vs  -m tcp： 是两个不同层面的东西，一个是说当前规则作用于 tcp 协议包，而后一是说明要使用iptables的tcp模块的功能 (--dport 等)  

**[iptables-extensions](http://ipset.netfilter.org/iptables-extensions.man.html)**

`iptables [-m name [module-options ...]] [-j target-name [target-options...]  `    



### How Calico works

[source](http://www.dasblinkenlichten.com/category/docker/)

configmap: cni网络配置、etcd的证书路径信息, calico_backend是bird

Secret：etcd-key cert ca信息： secret中的证书信息、和configmap中指定目录的数据时一样的么？一致 why？

Daemonset：用到了上面的信息

+ calico-node容器用到了etcd后端信息、etcd证书信息、etcd证书目录
+ install-cni容器用到了etcd后端信息、cni网络配置信息、挂载了主机的/opt/cni/bin目录和/etc/cni/etc.d/目录
  + 用于在每个node上创建正确的cni definitions，建完它就睡觉，这样k8s就可以通过cni来使用Calico了

Deployment：Calico Policy Controller，用到了用到了etcd后端信息、etcd证书信息、etcd证书目录，还有k8s apiserver信息

kubelet的--network-plugin=cni命令告诉我们使用本地CNI来提供容器网络， /etc/cni/net.d/中是cni configuration file，/opt/cni/bin存放cni plugins。这里面的内容都是install-cni这个容器创建的：

+ /opt/cni/bin/中如果没有插件，则创建
+ 创建calico-tls目录，创建相关证书
+ 创建kubeconfig文件，让cni与kube-apiserver交互

容器和外部namespace也有veth pair，但是外部ns中的veth并没有连到一个bridge上。容器内部的默认路由是一个不存在的ip local地址169.254.1.1，容器会使用arp协议来在网络中问谁的ip地址是它，该arp会到外部的veth，改veth反馈说是我：因为她开启了cat /proc/sys/net/ipv4/conf/cali182f84bfeba/**proxy_arp** ，满足条件下会说自己是那个IP地址。因为没有bridge，所以Calico会通过路由的方式来让容器与host通信。





## K8S 访问控制过程

![](./access-control-overview.png)



### 认证插件 Authentication

[http://www.dasblinkenlichten.com/kubernetes-authentication-plugins-and-kubeconfig/](http://www.dasblinkenlichten.com/kubernetes-authentication-plugins-and-kubeconfig/)

+ 如何使用插件呢？定义Config对象，该对象一般明文放在kubeconfig中。 
+ 认证模块有：Client Certificates, Password, and Plain Tokens, Bootstrap Tokens, and JWT Tokens (used for service accounts). 
+ 请求认证， API请求要么带着user、要么带着ServiceAccount、要么是匿名的
  + 如果指定了--insecure-port = 8080，则略过认证，localhost:8080即可访问。
  + http请求headers中带有对应的内容进行认证，认证成功后，获得请求中指定的username。
+ 在k8s中，不存储user这种资源, 由外部来管理，比如`An admin` distributing private keys，`a user store` like Keystone or Google Accounts, `a file` with a list of usernames and passwords 

**1 HTTP Basic Authentication** 

+ `--secure-port=6443`
+ `--basic-auth-file=/etc/kubernetes/basicauth.csv`  里面存放 [username], [password], [user], [group]

**2-1 Token Authentication**

+ `--secure-port=6443`
+ `--token-auth-file=/etc/kubernetes/tokenauth.csv`  里面存放 [token], [username], [user], [group]

**2-2 Service Account Tokens**

使用签名的tokens来验证请求：创建一个Secret，持有apiserver.crt和一个签名token；然后，1）either手动创建一个ServiceAccount，里面的secrets属性指向该Secret；2）or把该Secret放到pod中，pod内的SA可以使用。

- `--service-account-key-file` A file containing a PEM encoded key for signing bearer tokens. If unspecified, the API server’s TLS private key will be used.
- `--service-account-lookup` If enabled, tokens which are deleted from the API will be revoked.

**3 Client Certificate Authentication** 

apiserver需指定选项：（双向认证，如kubelet需要使用不同证书，则需指定kubelet相关的如下配置文件）

+ `--secure-port=6443`

+ `--client-ca-file=/etc/kubernetes/pki/ca.crt`  相当于CA的公钥+用ca.key签名的摘要

+ `--tls-cert-file=/etc/kubernetes/pki/apiserver.crt`  由CA签名的服务端证书文件

+ `--tls-private-key-file=/etc/kubernetes/pki/apiserver.key` 服务端私钥文件

  ​	apiserver首先创建自己的公钥私钥对，然后建立请求（server.seq，包含IP，域名，server的公钥）这些是明文信息，CA签发服务端证书：在这些明文信息上添加一个自己的签名：用某已知HASH算法生成这些明文信息的摘要，用ca.key加密这个摘要。

kubectl对应的kubeconfig需指定：

+ ```bash
  - cluster：
      certificate-authority-data： #原CA?或者是属于同一个根CA的证书文件
      server：$serverIP：6443
  ```

+ ```shell
  user:
    client-certificate-data: 由CA签名的客户端证书文件
    client-key-data: 客户端私钥文件
  ```

[TLS handshake](https://blog.csdn.net/ustccw/article/details/76691248)

+ 获取服务端apiserver.crt，将其中的明文信息用HASH算法生成一个摘要，然后使用ca.crt解开签名摘要，两个摘要对比弱相同则证书合法，于是就可以获取服务端的公钥。
+ 有了对方公钥，加密信息就能保证只有服务端才能打开（这里是**authentication**）。同时保证了只有对方才能看到我发送的消息。此时一般用于协商一个对称秘钥，通过该秘钥进行加密通信。

**3-2补充   证书、电子签名、ca、文件扩展名**

-----

*证书 = 公钥等明文信息 + CA.key（ HASH(公钥等明文)生成摘要 ）*

 *.crt 表示证书, .key表示私钥, .req 表示请求文件,.csr也表示请求文件, .pem表示pem格式，.der表示der格式 ，所有证书，私钥等都可以是pem,也可以是der格式* 

*der格式: 经过加密的二进制文件。* 

*pem格式：经过加密的文本文件，一般有下面几种开头结尾：* 

```shell
    -----BEGIN RSA PRIVATE KEY-----
    -----END RSA PRIVATE KEY-----
    or:
   -----BEGIN CERTIFICATE REQUEST-----
   -----END CERTIFICATE REQUEST-----
    or:
   ----BEGIN CERTIFICATE-----
  -----END CERTIFICATE-----
```

------

**4 Authentication Proxy  或者 Authentication Webhook**

上述代理，可以和LDAP, SAML, Kerberos, alternate x509 schemes 等整合





### 授权插件 Authorization

认证后获得了username/group，下面该根据**策略**Policy对请求进行授权了，一个请求包含：`username/group、action、object/nampespace/apigroup`

RBAC， WebHook

All of the default cluster roles and rolebindings are labeled with `kubernetes.io/bootstrapping=rbac-defaults`



#### Security Policy

1. policy是需要授权的，然后user或者目标pod的ServiceAccount才能使用。大部分pod不是user创建的，而是由ControllerManager创建的（Deployment、ReplicaSet），所以如果授权Controller可以访问策略，那么基本上Controller就可以访问所有pod了。所以，**一般是授权给pod的Service Account**
2. RBAC是标准k8s授权模式
3. 

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





## GCP容器安全系列报告

1. [Exploring container security: An overview](https://cloudplatform.googleblog.com/2018/03/exploring-container-security-an-overview.html)
2. [Exploring container security: Node and container operating systems](https://cloudplatform.googleblog.com/2018/04/exploring-container-security-Node-and-container-operating-systems.html)
3. [Exploring container security: Digging into Grafeas container image metadata](https://cloudplatform.googleblog.com/2018/04/exploring-container-security-digging-into-Grafeas-container-image-metadata.html)
4. [Exploring container security: Protecting and defending your Kubernetes Engine network](https://cloudplatform.googleblog.com/2018/04/exploring-container-security-protecting-and-Defending-your-Kubernetes-Engine-network.html)
5. [Exploring container security: Running a tight ship with Kubernetes Engine 1.10](https://cloudplatform.googleblog.com/2018/04/Exploring-container-security-Running-a-tight-ship-with-Kubernetes-Engine-1-10.html)
6. [Exploring container security: Using Cloud Security Command Center (and five partner tools) to detect and manage an attack](https://cloudplatform.googleblog.com/2018/05/Exploring-container-security-Using-Cloud-Security-Comma.html)
7. [Exploring container security: Isolation at different layers of the Kubernetes stack](https://cloudplatform.googleblog.com/2018/05/Exploring-container-security-Isolation-at-different-layers-of-the-Kubernetes-stack.html)

####1. 概述

容器仅仅是进程的边界，而VM提供的边界包括：app、资源、资源分配，所以你要用GCP。这里面提到的最重要的是runtime security，KubeCon EU 2018 有相关的报告，包括gVisor，[Secure Pods](https://kccnceu18.sched.com/event/Dqvf/secure-pods-tim-allclair-google-advanced-skill-level?iframe=no&w=100%&sidebar=yes&bg=no) ，[Kubernetes Runtime Security: What Happens If A Container Goes Bad?](https://kccnceu18.sched.com/event/Dqvx/kubernetes-runtime-security-what-happens-if-a-container-goes-bad-jen-tong-maya-kaczorowski-google-intermediate-skill-level?iframe=no&w=100%&sidebar=yes&bg=no) ，[Best Practices for Container Security at Scale](https://kccnceu18.sched.com/event/Dqv1/best-practice-for-container-security-at-scale-dawn-chen-zhengyu-he-google-intermediate-skill-level?iframe=no&w=100%&sidebar=yes&bg=no) 等

**基础设施安全**：咋使用k8s的这些工具

+ 身份认证与授权：RBAC提供对资源的细粒度访问；底层云基础设施提供，比如GCP的IAM
+ 日志：API 审计日志
+ 如何存储Secrets：在app层加密存入etcd； 在存储层加密然后存入etcd
+ 容器网络隔离：network policy；或者 You can also create [Private Clusters](https://cloud.google.com/kubernetes-engine/docs/how-to/private-clusters), in beta, to use only private IPs for your master and nodes. 

**软件供应链安全**：

+ 镜像、hostOS、app本身、镜像中app依赖的系统工具及库

**运行时安全：**能够检测/响应 对running container的威胁

+ 从baseline检测异常行为，基于系统调用、网络调用等信息
+ Forensics识别事件，基于日志、镜像
+ 阻止潜在威胁，通过对容器进行网络隔离、停止或重启容器等
+ 运行时策略或隔离？你的环境荀彧哪些行为

#### 2. Node操作系统和Container操作系统

攻击面：运行在node上的os + 容器的image。哈哈：前者请选用google的[Container-optimized OS (COS)](https://cloud.google.com/container-optimized-os/) ，后者请选用 [Google Container Registry](https://cloud.google.com/container-registry/) 

**COS安全设计：**

+ 只提供运行容器需要的packages，只开启容器运行需要的feature：降低攻击面
+ 根文件系统只读：启动时在kernel进行checksum检查。
  + home目录、日志、镜像分离在rootfs之外。永久存储
  + 配置文件/etc运行时注入，重启会消失，即Stateless Configuration。
+ 安全增强的内核：开启了LSM（g家自己的LoadPin LSM）、IMA、AUDIT、APPARMOR等 [kernel features](https://chromium.googlesource.com/chromiumos/overlays/board-overlays/+/master/overlay-lakitu/sys-kernel/lakitu-kernel-4_14/files/base.config#2950) 
+ 提供健全的默认配置：比如 [sysctl settings](https://chromium.googlesource.com/chromiumos/overlays/board-overlays/+/master/overlay-lakitu/chromeos-base/chromeos-base/files/00-sysctl.conf#84) that disable ptrace and unprivileged bpf, a locked down firewall,
+ 自动更新

**images安全点：**

+ 所有都是g自己维护的，知根知底
+ 不停的进行脆弱性扫描
+ 多层次的测试：kernel fuzz testing by [syzkaller](https://github.com/google/syzkaller), cluster-level Kubernetes tests, and several performance benchmarks 

#### 3. Grafeas项目 

对images提供结构化的，元数据访问API。利用Grafeas你可以track你的container images信息，甚至可以用 [in-toto](https://in-toto.github.io/)  基于Grafeas配置直接写attestations，然后Admissions Controls依此来拒绝/同意你的应用部署

+ build：容器什么时候创建的、谁创建的
+ Deployment History ：容器镜像的更新历史
+ Image Basis：容器运行的什么代码
+ 容器正在哪运行
+ Package Vulnerability：有没有已知的脆弱性？要不要施加相应的安全策略

举例子：Here at **Shopify**, we use Grafeas as the central place to store all the metadata（500k+images） about our deploys, helping us build six thousand containers a day, and making our lives easier. 

#### 4. 保护GKE网络 

Google Kubernetes Engine

**Restrict pod-to-pod traffic with a **[Kubernetes Network Policies](https://cloudplatform.googleblog.com/2018/03/Kubernetes-Engine-network-policy-is-now-generally-available.html) 

In Kubernetes Engine, these are supported using the Calico Network Plugin, created in collaboration with [Tigera](https://www.tigera.io/) 

#### 5. 啥来着

#### 6. 云安全工具（5个来自合作伙伴）来检测和管理攻击

针对的是运行时攻击

创建行为baseline，比如用kprobes, tracepoints, and [eBPF](http://www.brendangregg.com/ebpf.html) kernel inspection 。偏离这个baseline的行为视为异常，可采取相应的措施：alert、隔离容器（放到一个新网络中或网络不可达)、停止容器、重启容器、杀死容器。

分析安全事件：日志、snapshot等

5个小伙伴：**Aqua Security, Capsule8, Stackrox, Sysdig Secure, and Twistlock** 

#### 7.在不同的层级隔离容器

使用hypervisor，g家对KVM进行了安全加固put [significant effort into ensuring its security](https://cloudplatform.googleblog.com/2017/01/7-ways-we-harden-our-KVM-hypervisor-at-Google-Cloud-security-in-plaintext.html) 

trust boundary 就是你代码为此改变其信任级的地方

container： k8s中容器并未完全网络隔离，和部分容器共享网络；也会受到邻居影响（比如某邻居没配cgroup)

pod：网络隔离，使用了Network Policy；但也会受邻居影响；

Node：k8s可以被授权只访问该node上的pod需要的资源，使用防火墙规则隔离网络

Cluster：使用[per-cluster DNS](https://kubernetes.io/docs/concepts/services-networking/dns-pod-service/) 进行强网络隔离

Project：GCP project，IAM

Namespace: 提供RBAC控制，但是不要试图control resource quota, network, or policies 。它是帮你管理资源的，不是用来隔离的。

![](./Isolation-provided-by-layer-of-Kubernetes.png)

举了个例子：建一个多租户SaaS应用。

+ 避免邻居骚扰：在node层隔离关键workloads，部分坏了还能继续工作
+ 避免其它租户窃取你的信息：做好命名，组织对非授权node端口的访问(网络策略)，Cluster级
+ 关键数据：cluster级隔离



## KataContainer 介绍

[why-kata-containers-doesnt-replace-kubernetes](https://katacontainers.io/posts/why-kata-containers-doesnt-replace-kubernetes/)

整合了 [Intel® Clear Containers](https://github.com/clearcontainers/runtime) and [Hyper runV](https://github.com/hyperhq/runv)  ，提供vm的安全和容器的速度

#### CRI-O 与 Intel Clear Containers

[使用CRI-O使K8S可以同时拥有两种runtime](https://medium.com/cri-o/intel-clear-containers-and-cri-o-70824fb51811)

+ 高性能VM是通过两种技术获得的： VT-x 和 [KSM](https://www.linux-kvm.org/page/KSM) 技术，还有一个优化了的mini-OS
  + VT-x
  + KSM： a memory-saving de-duplication feature，合并私有匿名页 for memory sharing and boot speed 
  + mini-OS
+ Intel Clear Containers 的运行时叫做cc-runtime

#### Docker 工作原理：

```shell
dockerd -> containerd -> containerd-shim -> runC
        grpc         unix.Sock           OCI
```

+ conainterd，相当于实际的daemon，监听Unix socket, 暴露 gRPC endpoints. 处理 low-level 容器管理任务、存储、镜像分发、网络attachment。**提供workload**
+ containerd-shim，最终形成的一个容器进程，它通过指定容器ID、boundle目录、运行时二进制(runC) 的api来创建容器，(runC创建完就exit了，非驻留进程），**提供了配置文件**
+ runC命令行工具端，根据OCI的标准来创建和运行容器。处理与linux底层交互，包括权能、cgroups、ns等
+ 总结：`runC(workload + 配置) => container-shim进程`

#### kata融入Docker： [Docker’s runtime documentation](https://docs.docker.com/engine/reference/commandline/dockerd/#docker-runtime-execution-options)

+ 根据OCI标准，kata实现了替代runC的kata-runtime
+ `dockerd --add-runtime runc=runc --add-runtime custom=/usr/local/bin/kata-runtime`
+ ![](./dockerandkatacontainers.jpg)

####kata融入K8S:

+ k8s引入了CRI，容器运行时接口。这里接口的是CRI-shim，比如dockershim
  + cri-containerd
  + cri-o 支持[多个运行](https://medium.com/cri-o/intel-clear-containers-and-cri-o-70824fb51811)时同时存在，这样一个node上可以运行vm容器和普通容器。通过pod的annotations可以让CRI-O知道是启动一个容器pod还是启动一个VM的pod
  + frakti
+ kata为接入K8S，提供了两种方法：
  + 实现了一个OCI标准的 kata-runtime，该runtime可以连向cri-containerd and CRI-O 
  + 实现了一个硬件虚拟化运行时API，来让CRI-shims用，这是一种更加CRI-native的方法，frakti就是其中一种。
+ ![](./kubernetesandkatacontainers.jpg)



## 使用SharedInformer自己实现一个Kube Controller

https://engineering.bitnami.com/articles/kubewatch-an-example-of-kubernetes-custom-controller.html

+ 一个controller负责一种资源
+ 两个组件，一个Informer/SharedInformer监控某对象的事件，把事件交给另一个组件Workqueue
+ 不可能不停地给apiserver要信息吧，而且控制器也只是要变化事件，那就维护一个本地cache吧client-go做这件事，提供ListWatcher接口：初始list + watch某资源。Informer这个结构就做了这件事

Informer：接口， 展示+监控+提供处理钩子。三大件如下

1. `ListWatcher`结构，包含listFunc和watchFunc函数，负责展示和监控某***ns***下的*某**标签***的某***<u>资源</u>***
2. `ResourceEventHandlerFuncs struct`，包含AddFunc、UpdateFunc、DeleteFunc, 负责接收到事件后的处理。Informer 并不知道各个controller什么状态了，所以ResourceEventHandlers只是简单地把事件放到各自的待处理队列中了Workqueue
3. `ResyncPeriod`: 除被动监听外，控制器还可以主动sync，执行UpdateFunc，该值就是主动更新周期时间

SharedInformer：接口， 基本都是用这个

1. Informer是某控制器自己用，但是有很多controller啊，请求的东西有可能重叠，所以弄了个共享Informer
2. 跟Informer一样，也是三大件

Workqueue：

+ *client-go/util/workqueue* 
+ 以map的key的形式存notification，而且是等缓存同步之后再处理。

## Linux Namespace

#### 系统调用

clone()   创建新进程，创建新ns，将新进程放入新ns。可以使用参数指定多类新ns

+ `clone(container_main, container_stack+STACK_SIZE, CLONE_NEWUTS | CLONE_NEWIPC | SIGCHLD, NULL)`

unshare()    不创建新进程，创建新ns，将当前进程加入新ns。

setns()         不创建新进程，不创建ns，将当前进程加入一个已经存在的ns。

对于pid namespace，unshare/setns，并不将当前进程加入新ns，而是子进程加入新的ns，因为getpid()返回的应该是个不变的pid，不能改变。

#### 内核结构

`task_struct->struct cred -> struct nsproxy -> ust_ns/ips_ns/mnt_ns/net_ns/user_ns`

#### 用户层工具

unshare   `unshare -U/m/i/n/p /bin/bash` 

ip netns 

nsenter

####各NS详解

User Namespace除了隔离用户ID和用户组ID之外，还对每个Namespace进行了Capability的隔离和控制。

用户在新namespace中有全部权限，但是他在创建他的父namespace中不含任何权限。就算调用和创建他的进程有全部权限也是如此。所以哪怕是root用户调用了clone()在user namespace中创建出的新用户在外部也没有任何权限 



## Linux CGroup

https://juejin.im/post/5a113fd851882575cb73b1a5

本质上来说，cgroups是内核附加在程序上的一系列钩子（hooks），通过程序运行时对资源的调度触发相应的钩子以达到资源追踪和限制的目的。 

+ Resource limitation: 限制资源使用，比如内存使用上限以及文件系统的缓存限制。
+ Prioritization: 优先级控制，比如：CPU利用和磁盘IO吞吐。
+ Accounting: 一些审计或一些统计，主要目的是为了计费。
+ Control: 挂起进程，恢复执行进程。

术语

- task（任务）：cgroups的术语中，task就表示系统的一个进程。
- cgroup（控制组）：cgroups 中的资源控制都以cgroup为单位实现。cgroup表示按某种资源控制标准划分而成的任务组，包含一个或多个子系统。一个任务可以加入某个cgroup，也可以从某个cgroup迁移到另外一个cgroup。
- subsystem（子系统）：cgroups中的subsystem就是一个资源调度控制器（Resource Controller）。比如CPU子系统可以控制CPU时间分配，内存子系统可以限制cgroup内存使用量。子系统就那几类
- hierarchy（层级树）：hierarchy由一系列cgroup以一个树状结构排列而成，每个hierarchy通过绑定对应的subsystem进行资源调度。hierarchy中的cgroup节点可以包含零或多个子节点，子节点继承父节点的属性。整个系统可以有多个hierarchy

 #### 查询cgroup及子系统挂载状态

- 查看所有的cgroup：lscgroup
- 查看所有支持的子系统：lssubsys -a
- 查看所有子系统挂载的位置： lssubsys –m
- 查看单个子系统（如memory）挂载位置：lssubsys –m memory

#### 层次结构

cgroup（层级）->subsystem（包括cpu/mem/cpuset/net...)->Hierarchy(文件系统)

#### 使用方法

首先，挂载cgroups

`mount -t tmpfs cgroups /sys/fs/cgroup` 

其次，在根Hierarchy上创建子系统

```shell
/sys/fs/cgroup/cpu/lyz/cpu.cfs_quota_us
/sys/fs/cgroup/cpu/lyz/tasks
#cgroup下的cpu子系统中，有一个lyz 层级，其内的tasks保存加入进来的进程，cpu.filename保存限制参数
```

然后，创建一个Hierarchy，并**挂载子系统**

```shell
mkdir /sys/fs/cgroup/cg1   
# 格式： mount -t cgroup -o subsystems name /cgroup/name
mount –t cgroup –o cpu,memory cpu_and_mem /sys/fs/cgroup/cg1
# 于是 cg1/下有cpu_and_mem文件夹，管控的是cpu，memory
```

#### 使用规则

1. 同一个hierarchy可以附加多个子系统，比如`mount -t cgroup -o cpu,memroy cpu_mem /sys/fs/cgroup/cg1`
   1. 就是某文件夹代表的是多个子系统。
2. 一个子系统下有一个hierarchy，其下面不能再包含，其已属于其它subsystem的hierarchy。
   1. 不能再被挂载一个Hierarchy
3.  一个task不能属于同一个hierarchy的不同cgroup 
   1.  `PREFIX/cg1/tasks `和` PREFIX/cg2/tasks `不能含相同pid
4. 进程创建的子进程默认属于同一个cgroup，但是可以自由移动

#### CGroup的子系统

- blkio： 这个subsystem可以为块设备设定输入/输出限制，比如物理驱动设备（包括磁盘、固态硬盘、USB等）。
- cpu： 这个subsystem使用调度程序控制task对CPU的使用。
- cpuacct： 这个subsystem自动生成cgroup中task对CPU资源使用情况的报告。
- cpuset： 这个subsystem可以为cgroup中的task分配独立的CPU（此处针对多处理器系统）和内存。
- devices 这个subsystem可以开启或关闭cgroup中task对设备的访问。
- freezer 这个subsystem可以挂起或恢复cgroup中的task。
- memory 这个subsystem可以设定cgroup中task对内存使用量的限定，并且自动生成这些task对内存资源使用情况的报告。
- perfevent 这个subsystem使用后使得cgroup中的task可以进行统一的性能测试。{![perf: Linux CPU性能探测器，详见[perf.wiki.kernel.org/index.php/M…](https://link.juejin.im?target=https%3A%2F%2Fperf.wiki.kernel.org%2Findex.php%2FMainPage%5D%7D)
- *net_cls 这个subsystem Docker没有直接使用，它通过使用等级识别符(classid)标记网络数据包，从而允许 Linux 流量控制程序（TC：Traffic Controller）识别从具体cgroup中生成的数据包。

 

 

# ToRead

1. [K8S十大使用技巧](https://mp.weixin.qq.com/s/YnnhRh9HV20gbd5hBBLNig)
2. [KubeCon 2018视频资源](https://github.com/cncf/presentations/blob/master/chinese/2018Copenhagen.md)



 ![kubernetes-pod-cheatsheet.png](./kubernetes-pod-cheatsheet.png)

 

 

 

 

 

 
