---
layout: post
title: Go-Technique
categories: [Mastered]
tags: Mastered
---

## Go

1. goroutine 开销很小，类似栈分配的消耗。其实是一个用户态线程，go自己有个用户态调度器sched，维护一组gorouine让其在某个内核线程上跑，sched知道啥时候该让某个goroutine停换另一个跑。每个goroutine其实就是在heap上分配了一些空间模拟stack。每个内核线程会有一个上下文P，该上下文和shed一起管理一组goroutine，`runtime.GOMAXPROCS(x)`来设置有几个P，也就是有几个内核线程来跑该程序。

2. chan 会立即阻塞，该goroutine内后面的代码不会执行，直到接收到，或者发送的东西被人接收到

   1. `[var] <- chan`  等待chan有值可以拿出来，这句话就可以执行了，比如另一个goroutine中执行了一句chan <- var

3. select 会任意选择其中一个不被阻塞的case语句执行，一般配合for死循环执行

4. Interface类型想象成一个类，实现了Interface中函数的struct想象成类的实例。**那么参数是interface的话，实参就可以是对应的struct**。当然参数也必须是接口，就可以接受任意struct了。比类好在哪里呢？可以是任意struct，里面有任意属性，包括空struct{}，只要在该struct上定义了interface的方法。**那么空接口类型可以接收任意类型参数**  `reflect.TypeOf(i interface {}) reflect.Type`

   1.  interface中不能包含变量，只能是方法和其它接口

   2.  一个类型不用显式去定义实现某个接口，只要包含所有interface中定义的方法，这个类型就默认实现了这个接口

   3.  多个类型可以实现相同的接口，一个类型可以实现多个接口， 一个类型实现接口的同时，还可以定义属于自己的方法

   4. 一个interface的属性中除了可包含method外，还可以包含另一个接口（子接口)，那么**父接口可以直接用子接口的函数**, 即接口包含所嵌套接口的所有方法

      1. ```go
         type SharedInformer interface{
             Run(stopCh <- chan struct{})
         }
         type SharedIndexInformer interface{
             SharedInformer,
             AddIndexers(indexers Indexers) error
             GetIndexer() Indexer
         }
         type sharedIndexInformer struct{}
         s := sharedIndexInformer{struct{}}
         s.Run(stopCh)
         ```

      2. 最后一句s.Run（）是可以执行的

5. 一个**struct中可以包含interface类型对象**，那么该结构体可以直接使用该类型对象的方法？不是！但是可以把该struct赋值给某个接口，这个接口就可以使用这个方法了。

6. we can define a method for any **named** type except pointers and interfaces 可以在除了指针和接口外的任何类型（named表示type过的）上定义方法（可以是普通方法，也可以是接口的方法）；**函数**也可以拥有方法

   1. ```go
      // The HandlerFunc type is an adapter to allow the use of
      // ordinary functions as HTTP handlers.  If f is a function
      // with the appropriate signature, HandlerFunc(f) is a
      // Handler object that calls f.
      type HandlerFunc func(ResponseWriter, *Request)
      func (f HandlerFunc) ServeHTTP(w ResponseWriter, req *Request) {
          f(w, req)  //起了回调函数的作用，不用单独定义一个chan来调用函数了
      }
      
      func ArgServer(w http.ResponseWriter, req *http.Request) {
          fmt.Fprintln(w, os.Args)
      }
      //因为实现了ServeHTTP方法，所以可以被http.Handle调用
      http.Handle("/args", http.HandlerFunc(ArgServer))
      //这里的http.HandlerFunc()是执行的类型转换，因为ArgServer函数与HandlerFunc类型有相同的signature
      ```

   2. 

7. 结构体实现的方法可以在结构体+指针上调用。但指针实现的接口，只能是指针赋值给接口。 

   1. ```go
      type Configurator interface {run()}
      type configFactory struct{}
      func (c *configFactory) run(){}
      func NewConfigurator() Configurator{
          return &configFactory{}
          //return configFactory 是不可以的
      }
      ```

8. 接口也可以被包含了该接口的struct赋值，refect.TypeOf(接口)返回的却是结构体类型，但是确只能使用接口方法

   1. ```go
      type schedulerConfigurator struct{Configurator, name string} //只是为了使用其方法，不需要名称
      c := NewConfigurator()
      c = &schedulerConfigurator{c, "liyanzhao"}  //这个赋值是可以的
      //c.run() is OK; c.name fails
      ```

   2. 这里更新接口的values是有意义的么？毕竟只能使用的还是接口方法，那么是不是schedulerConfigurator上可以定义覆盖原实体的接口方法呢？**可以**，而且可以只覆盖部分方法，但是configFactory就必须实现所有的方法。

      1. 在源码中可以发现确实覆盖了Configurator的Create()函数，默认configFactory的Create函数实现是f.CreateFromProvider(DefaultProvider)
      2. 覆盖后是sc.Configurator.CreateFromProvider(sc.algorithmProvider)

   3. 接口可以赋值给结构体么？？？即能恢复成原来的struct么？

9. [reflect包](https://studygolang.com/articles/1251)

   1. reflect.Type 是一个接口对象，里面的方法包括Field，Name，String等
   2. reflect.Typeof( * ) refect.Type，返回某变量的reflect.Type 

10. goroutine、chan、sync.WaitGroup、select等是并行相关

11. iota是0开始，自动增加，比如

    1. ```
       const (
           Sunday = iota  // Sunday = 0
           Monday         // Monday = 1
           ...
           Saturday       // Saturday = 6
       )
       ```

12. rune是处理utf-8，比如汉字，相关的内容what23

13. import "log"  两种用法

    1. 第一种是输向标准错误，log.Println(), log.Fatal()
    2. 第二种是自建一个logger, logg = log.New(out io.Writer, 格式等); 然后logg.Println()

## Python
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