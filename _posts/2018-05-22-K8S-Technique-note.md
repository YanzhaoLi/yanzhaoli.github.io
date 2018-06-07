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



### Understanding CNI - Jon Langemak

[Source](http://www.dasblinkenlichten.com/understanding-cni-container-networking-interface/)

首先，container runtime先创建一个网络命名空间`ip netns add NAME`

接着，调用插件，讲该网络命名空间接入网络：

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





![kubernetes-pod-cheatsheet.png](./kubernetes-pod-cheatsheet.png)