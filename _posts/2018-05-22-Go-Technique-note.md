---
layout: post
title: Go-Technique
categories: [Mastered]
tags: Mastered
---

## Go

1. goroutine 开销很小，类似栈分配的消耗。其实是一个用户态线程，go自己有个用户态调度器sched，维护一组gorouine让其在某个内核线程上跑，sched知道啥时候该让某个goroutine停换另一个跑。每个goroutine其实就是在heap上分配了一些空间模拟stack。每个内核线程会有一个上下文P，该上下文和shed一起管理一组goroutine，`runtime.GOMAXPROCS(x)`来设置有几个P，也就是有几个内核线程来跑该程序。

2. chan 会立即阻塞，后面的代码不会执行，直到接收到，或者发送的东西被人接收到

3. goroutine、chan、sync.WaitGroup、select等是并行相关

4. iota是0开始，自动增加，比如

   1. ```
      const (
          Sunday = iota  // Sunday = 0
          Monday         // Monday = 1
          ...
          Saturday       // Saturday = 6
      )
      ```

5. rune是处理utf-8，比如汉字，相关的内容what23

6. import "log"  两种用法

   1. 第一种是输向标准错误，log.Println(), log.Fatal()
   2. 第二种是自建一个logger, logg = log.New(out io.Writer, 格式等); 然后logg.Println()

## Python
1. ​

## Shell
1. ​

## C/C++
1. [The Architecture of Open Source Applications](http://aosabook.org/en/index.html)
2. [Awesome Courses abroad](https://github.com/prakhar1989/awesome-courses)
3. [Maglev--A Fast and Reliable Software Network Load Balancer](../Maglev--A-Fast-and-Reliable-Software-Network-Load-Balancer.pdf)
4. [Preshing on Programming Blog](http://preshing.com/)
5. [distributed-systems-readings](http://henryr.github.io/distributed-systems-readings/)
6. [MIT-Distributed-System](http://nil.csail.mit.edu/6.824/2015/schedule.html)
7. [StackOverflow-Architecture-Serials](http://nickcraver.com/blog/2016/02/03/stack-overflow-a-technical-deconstruction/)
8. [Go-libpcap Packet Capture](http://www.devdungeon.com/content/packet-capture-injection-and-analysis-gopacket#gopacket#)
9. [A Distribted System Reading list](https://dancres.github.io/Pages/?url_type=39&object_type=webpage&pos=1)
10. [并发之痛](http://weibo.com/ttarticle/p/show?id=2309403948698710187414)
11. [go by example](https://gobyexample.com/?url_type=39&object_type=webpage&pos=1)
12. [paxos-wechat](http://mp.weixin.qq.com/s?__biz=MzI4NDMyNTU2Mw==&mid=2247483695&idx=1&sn=91ea422913fc62579e020e941d1d059e#rd)
13. [Write good C++](https://github.com/isocpp/CppCoreGuidelines)
14. [Large-scale system Stanford](https://cs.stanford.edu/~matei/courses/2015/6.S897/?from=timeline&isappinstalled=0)
15. [bash, sed, awk](http://www.grymoire.com/Unix/)
16. [sectools.org](http://sectools.org/)
17. [perf教程](https://www.dropbox.com/s/h5p5r7c0utj33mg/perf-BPF-workshop-final.pdf?dl=0)
## JS
1. [Prepare Well for your FrontEnd Interview](http://www.1point3acres.com/bbs/thread-104335-1-1.html)
  + [Guangyi Zhou](https://cn.linkedin.com/in/guangyizhou)
  + 超详细的面试准备，充足的学习资料链接，常见问题的常见答案Secrets-of-the-JavaScript-Ninja.pdf
  + [Secrets-of-the-JavaScript-Ninja.pdf](../Secrets-of-the-JavaScript-Ninja.pdf)
  + [JavaScript: the good parts.pdf](../javascript_the_good_parts-en.pdf); [JavaScript语言精粹修订版](../JavaScript-the-good-parts-cn.pdf)
  + [what-is-the-difference-between-client-side-and-server-side-programming](https://stackoverflow.com/questions/13840429/what-is-the-difference-between-client-side-and-server-side-programming)
  + [what-happens-when-you-type-in-a-url-in-browser](https://stackoverflow.com/questions/2092527/what-happens-when-you-type-in-a-url-in-browser)

2. [React Websites with Source Code](https://react.rocks/tag/FullStack)
3. [Web性能权威指南.pdf](../Web性能权威指南.pdf)
4. [WeChat-Development](https://mp.weixin.qq.com/debug/wxadoc/dev/?t=1474644090069)
5. [wechat Awesome Tutorials](https://github.com/Aufree/awesome-wechat-weapp)