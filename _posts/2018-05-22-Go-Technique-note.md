---
layout: post
title: Go-Technique
categories: [Mastered]
tags: Mastered
---



# #

类型转换，转换成你想要的类型，就能调用该类型上实现的方法了。否则，必须在该类型上实现该方法才能用

```go
type Sequence []int
sort.IntSlice(s).Sort()
#sort包中有一个类型叫IntSlice，其实就是type IntSlice []int, 将s类型转化为IntSlice，再调用Sort()方法
```





### goroutine channel select wait

1. goroutine 开销很小，类似栈分配的消耗。其实是一个用户态线程，go自己有个用户态调度器sched，维护一组gorouine让其在某个内核线程上跑，sched知道啥时候该让某个goroutine停换另一个跑。每个goroutine其实就是在heap上分配了一些空间模拟stack。每个内核线程会有一个上下文P，该上下文和shed一起管理一组goroutine，`runtime.GOMAXPROCS(x)`来设置有几个P，也就是有几个内核线程来跑该程序。

2. chan 会立即阻塞，该goroutine内后面的代码不会执行，直到接收到，或者发送的东西被人接收到

   1. `[var] <- chan`  等待chan有值可以拿出来，这句话就可以执行了，比如另一个goroutine中执行了一句chan <- var

3. close()命令是通知所有等待的channel的，获得数据，但是需要给时间，不然有可能信号还没送到

   ```go
   stop := make(chan struct{})
   go f1(stop)
   go f2(stop)
   close(stop)
   time.Sleep(time.Second * 1)  //如果此时立刻结束主函数，那么两个routine可能收不到信号
   ```

   

4. select 会任意选择其中一个不被阻塞的case语句执行，一般配合for死循环执行

5. goroutine、chan、sync.WaitGroup、select等是并行相关

### struct 和 interface

1. Interface类型想象成一个类，实现了Interface中函数的struct想象成类的实例。**那么参数是interface的话，实参就可以是对应的struct**。当然参数也必须是接口，就可以接受任意struct了。比类好在哪里呢？可以是任意struct，里面有任意属性，包括空struct{}，只要在该struct上定义了interface的方法。**那么空接口类型可以接收任意类型参数**  `reflect.TypeOf(i interface {}) reflect.Type`

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

2. 一个**struct中可以包含interface类型对象**，那么该结构体可以直接使用该类型对象的方法？不是！要么有一个interface实体放到struct中，要么struct自己实现该interface的方法。

3. we can define a method for any **named** type except pointers and interfaces 可以在除了指针和接口外的任何类型（named表示type过的）上定义方法（可以是普通方法，也可以是接口的方法）；**函数**也可以拥有方法

   1. http.Handle(路径, handler); //handler是一个实现了Handler接口的ServeHTTP()方法的实体

   2. ```go
      // The HandlerFunc type is an adapter to allow the use of ordinary functions as HTTP handlers.  If f is a function with the appropriate signature, HandlerFunc(f) is a Handler object that calls f.
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

4. 结构体实现的方法可以在结构体+指针上调用。但指针实现的接口，只能是指针赋值给接口。 

   1. ```go
      type Configurator interface {run()}
      type configFactory struct{}
      func (c *configFactory) run(){}
      func NewConfigurator() Configurator{
          return &configFactory{}
          //return configFactory 是不可以的
      }
      ```

5. 接口也可以被包含了该接口的struct赋值，refect.TypeOf(接口)返回的却是结构体类型，但是确只能使用接口方法

   1. ```go
      type schedulerConfigurator struct{Configurator, name string} //只是为了使用其方法，不需要名称
      c := NewConfigurator()
      c = &schedulerConfigurator{c, "liyanzhao"}  //这个赋值是可以的
      //c.run() is OK; c.name fails
      ```

   2. 这里更新接口的values是有意义的么？毕竟只能使用的还是接口方法，那么是不是schedulerConfigurator上可以定义覆盖原实体的接口方法呢？**可以**，而且可以只覆盖部分方法，但是configFactory就必须实现所有的方法。

      1. 在源码中可以发现确实覆盖了Configurator的Create()函数，默认configFactory的Create函数实现是f.CreateFromProvider(DefaultProvider)
      2. 覆盖后是sc.Configurator.CreateFromProvider(sc.algorithmProvider)

   3. 接口可以赋值给结构体么？？？即能恢复成原来的struct么？ 表示不能，而且基本不会定义接口对应的变量

6. **匿名的fields可以实现其它语言中继承的功能** 

   1. struct包含，比如Player包含了User，如果是**匿名**包含（即不给User域起名字）则可以直接使用定义在User上的方法，否则必须p.u.Method()
   2. 在一个struct内，对于每种类型，只能有一个匿名类型的field , 因为匿名类型可以作为该匿名的域名城

### go

1. [reflect包](https://studygolang.com/articles/1251)

   1. reflect.Type 是一个接口对象，里面的方法包括Field，Name，String等
   2. reflect.Typeof( * ) refect.Type，返回某变量的reflect.Type 

2. iota是0开始，自动增加，比如

   1. ```
      const (
          Sunday = iota  // Sunday = 0
          Monday         // Monday = 1
          ...
          Saturday       // Saturday = 6
      )
      ```

3. rune是处理utf-8，比如汉字，相关的内容what23，rune("s") 返回的是ascii码数值，如果是汉子，就是utf-8

4. import "log"  两种用法

   1. 第一种是输向标准错误，log.Println(), log.Fatal()
   2. 第二种是自建一个logger, logg = log.New(out io.Writer, 格式等); 然后logg.Println()

5. 按域分割字符串 ``` func strings.Fields(string) []string {}```

6. array ... 是拆开变量，类似于python中的 *list

#### 函数传参

1. 函数传参，是按values传参，自定义的struct，array等都是全copy；引用类型传参加&

2. 引用类型，默认采用传引用的方法：slice、map、interface、channel

3. 传递同类型未知个数参数使用  `varname ...Type`，函数内部转化为[]int{}，即slice

4. 传递不同类型的未知个数参数呢？使用空接口interface{}。尽量别这么用哈

   1. ```go
      func PrintType(variables ...interface{}) {
          for _, v := range variables {
              switch v.(type) {
              case int:
                  fmt.Println("type is int %d", v)
              default:
                  fmt.Println("other type %v", v)
              }
          }
      }
      
      func showFunctionMultiInterfaceParameters() {
          lemon.PrintType(5, "aaaa")
          var2 := []interface{}{6, 7, 9, "bbb", "ccc"}
          lemon.PrintType(var2...)
      }
      ```

5. 



### package

1. 不能对来自其他package中的struct定义方法 

2. 只有首字母大写的identifier（constant、variable、type、function、struct field，...）可以被import，起到了public的作用

3. 把struct弄成小写，函数构造器弄成大写的，那么在包外，就只能使用构造器来申请资源了

   1. ```go
      pakcage matrix
      type matrix struct {
          ...
      }
      function NewMatrix(params) *matrix {
          m := new(matrix)
          //m is initialized
          return m
      }
      ```

   2. ```go
      package main
      import "matrix"
      wrong := new(matrix.matrix)    //will not compile(matrix is private)
      right := matrix.NewMatrix(...)    //the ONLY way to instantiate a matrix
      ```

4. 

### Go 安装

+ 官网下载go，配置GOROOT GOPATH 

+ 安装vim-go, 使用插件 [vim-pathogen](https://github.com/tpope/vim-pathogen )

+ ```bash
  mkdir -p ~/.vim/autoload ~/.vim/bundle  
  curl -LSso ~/.vim/autoload/pathogen.vim https://tpo.pe/pathogen.vim
  echo <<EOF >> ~/.vimrc
  	execute pathogen#infect()  
  	syntax on  
  	filetype plugin indent on  
  	EOF
  cd ~/.vim/bundle/  && git clone https://github.com/fatih/vim-go.git  
  ```

+ 调试工具Delve：

  + git clone https://github.com/go-delve/delve.git
  + go get -v github.com/go-delve/delve/cmd/dlv
    + git clone之后，其路径需要与go get的路径一致

+ vscode go

  + 打开一个文件夹，创建一个.go文件，会自动提示你安装vscode go插件
    + mkdir $GOPATH/src/golang.org/x  && cd $GOPATH/src/golang.org/x
    + git clone https://github.com/golang/tools.git tools
    + go get -v github.com/sqs/goreturns
  + Run Build Task 会提示你创建task.json，把command改成go run即可
  + Start Debugging 应该是可以直接使用的


#### import "sync"

除了sync.Once和sync.WaitGroup类型外，其它类型大多用于low-level library routines，high-level的同步工作请使用channels和communication

#### import “container/heap"

heap.Init(h)

heap.Push(h, 3)

heap.Pop()





#### golang 反射的应用

http://licyhust.com/golang/2017/10/30/golang-reflect/    + [官网](https://golang.org/pkg/reflect/)

两大类型Value和Type + interface{}桥梁 => 三大定律

- 反射可以将“接口类型变量”转换为“反射类型对象”
- 反射可以将“反射类型对象”转换为“接口类型变量”。
- 如果要修改“反射类型对象”，其值必须是“可写的”（settable）

用于操作任意类型对象

- 修改结构体信息
- 获取结构信息

```go
func reflect.TypeOf(i interface{}) reflect.Type
# 返回的是一个接口，该接口代表了i的动态类型
func reflect.ValueOf(i interface{}) reflect.Value
# 返回的是一个结构体，代表了i的动态值
```

reflect包中有以Type和Value作参数的函数，最重要的是就是上面的TypeOf和ValueOf

reflect.Type 接口内有很多方法，接口对应的动态类型必须实现了这些方法

reflect.Value上也定义了一些方法

## To Read => Summary

[工业级go编程 Go for Industrial Programming](https://peter.bourgon.org/go-for-industrial-programming/#structuring-your-code-and-repository)

[图解Go 并发](https://medium.com/@trevor4e/learning-gos-concurrency-through-illustrations-8c4aff603b3)

[重读Serverless Architecture](https://blog.symphonia.io/revisiting-serverless-architectures-29f0b831303c)

[如何组织你的go应用](https://github.com/katzien/talks/blob/master/how-do-you-structure-your-go-apps/gopherconiceland-2018-06-02/slides.pdf)

[创建Search微服务](https://ryanmccue.ca/how-to-create-a-search-microservice/)

[go高效比较字符串](https://www.digitalocean.com/community/questions/how-to-efficiently-compare-strings-in-go)

[go胜利之后](http://redmonk.com/jgovernor/2018/05/25/kubernetes-won-so-now-what/)

[go命令行调试cheatsheat](https://github.com/trstringer/cli-debugging-cheatsheets/blob/master/go.md)

[https://www.weave.works/blog/kubernetes-horizontal-pod-autoscaler-and-prometheus](https://www.weave.works/blog/kubernetes-horizontal-pod-autoscaler-and-prometheus)

[https://speakerd.s3.amazonaws.com/presentations/1ff354ef94f24ca69fd7063684f3af99/The_Robustness_of_Go.pdf](https://speakerd.s3.amazonaws.com/presentations/1ff354ef94f24ca69fd7063684f3af99/The_Robustness_of_Go.pdf)

[https://www.weave.works/blog/kubernetes-best-practices](https://www.weave.works/blog/kubernetes-best-practices)

[Code Like the Go Team](https://talks.bjk.fyi/bketelsen/talks?p=gcru18-best#/)

+ 完成同一个功能的不同版本，让它们有共同的父package
+ app = domain types + Services
  + domain type 描述类型和行为，是app的实体。每个单独的package。struct表示类型+interface表示操作
  + Services ：domain接口的实现，由dependency管理(外部数据+传输逻辑)，每个dependency一个package。
  + 举例：struct Product，对应产品存储方法 interface ProductService，依赖外部存储比如nfs
+ 命名
  + 标量用重复字符代表集合/数组等，var tt []*Thing
  + 同一个Domain Type下有多个类型，那么一个Package，每个类型一个文件
  + 尽量避免else
  + 某package内的变量命就不要包含包信息了，比如log.LogInfo -> log.Info()

[Checklist for Go projects](https://blog.depado.eu/post/checklist-for-go-projects)

+ 介绍一个go项目所需要的工具、配置、编译等等。

[go internals](https://github.com/teh-cmc/go-internals/blob/master/chapter2_interfaces/README.md)

+ 介绍了go interfaces和method的内部实现方式，通过汇编展示

[we_are_kubernetes_developers_ask_us_anything/](https://www.reddit.com/r/kubernetes/comments/8b7f0x/we_are_kubernetes_developers_ask_us_anything/)

+ 问了啥？回答了啥？

[https://blog.chewxy.com/2018/03/18/golang-interfaces/](https://blog.chewxy.com/2018/03/18/golang-interfaces/)

+ Accept interfaces, return structs 

[https://kubernetes.io/blog/2018/03/principles-of-container-app-design/](https://kubernetes.io/blog/2018/03/principles-of-container-app-design/)

[https://www.weave.works/blog/kops-vs-kubeadm](https://www.weave.works/blog/kops-vs-kubeadm)

[https://github.com/enocom/gopher-reading-list](https://github.com/enocom/gopher-reading-list)

[编写和优化Go代码](https://github.com/dgryski/go-perfbook/blob/master/performance-zh.md)

+ 介绍了很多优化技巧，可以看一看

[https://golang.google.cn/ref/mem](https://golang.google.cn/ref/mem)

