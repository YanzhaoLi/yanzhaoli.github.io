---
layout: post
title: Shell-Technique
categories: [Mastered]
tags: Mastered
---



### Bash cheatssheets

[bash cheatsheets](https://jimmysong.io/cheatsheets/bash)



### CentOS Ubuntu 软件包 管理 安装

#### Ubuntu

只下载不安装 `apt-get install **-d**  package`

+ 下载位置：/var/cache/apt/archives/
+ `ls -c | head -n 6 | awk 'NR>1{print $1}'`  # 按时间排序后提取出前5个

解压deb包   `ar   -x   *.deb`

搜索deb包  `apt-cache search package`

#### CentOS

只下载不安装 yumdownloader package   当前目录

解压deb包      `rpm2cpio  *.rpm | cpio -idv`

#### 查看tar包

+ `tar -tvf *.tar`
+ `gzip -dc file.tar.gz | tar tvf -`
+ `bzip2 -dc file.tar.bz2 |tar tvf -`



##### shell { }  变量替换
```shell
for i in {1,2,3}.png; do echo $i; done

for i in {1...100}.jpg; do convert $i ${i%%.*}.png; done
```

##### shell 正则表达式 比较 =~ operator

```shell
if [[ $string =~ $extend_epr ]]; then 
	${#BASH_REMATCH[*]} #提取出匹配组数量
	$BASH_REMATCH[0]    #整体匹配
	$BASHE_REMATCH[1]   #第一个submatch组，就是带括号的
```



### [awk](http://www.grymoire.com/Unix/AwkRef.html) [-arg] 'PATTERN{ACTION}'

```shell
BEGIN {}
PATTERN {}  #pattern can be regrex, $1 > 0, ...
END {}
#awk的命令有下面这些
if ( conditional ) statement [ else statement ]
while ( conditional ) statement
for ( expression ; conditional ; expression ) statement
for ( variable in array ) statement
break
continue
{ [ statement ] ...}
variable=expression
print [ expression-list ] [ > expression ]
printf format [ , expression-list ] [ > expression ]
next 
exit
```

##### awk Pattern

- 如果不指定pattern，默认为true，即执行action
- pattern相当于内部if(condition)

```
BEGIN
END
/regular expression/
relational expression
pattern && pattern
pattern || pattern
pattern ? pattern : pattern
(pattern)
! pattern
pattern1, pattern2 - Range pattern
```



##### awk支持字符串与正则表达式的比较条件

```bash
word !~ /START/
lawrence_welk ~ /(one|two|three)/
#左侧是字符串，右侧是RE
```

##### awk 删除某fields

```shell
#!/usr/bin/awk -f
{
  $1="";
  $3="";
  print;
}
#输出四个fields，两个内容为空，但分隔符有三个
#!/usr/bin/awk -f
{
  print $2, $4;
}
#输出两个fields，分隔符只有一个
```

##### awk特殊变量，不需要使用$哦

- *字段分隔符*：`{BEGIN{FS=":"}}` <=> `awk -F: '{ }'` 

  - 动态处理分隔符: 如何判断一行有没有:，使用正则表达式；改变分隔符后更新```$0=$0```

  - ```shell
    #!/bin/awk -f
    {
    	if ( $0 ~ /:/ ) {
    		FS=":";
    		$0=$0
    	} else {
    		FS=" ";
    		$0=$0
    	}
    	#print the third field, whatever format
    	print $3
    }
    ```

- *输出分隔符OFS*,  ```print $2, $3```中，```$2和$3```之间的分隔符由OFS变量指定，默认space

- *字段总数NF*，number of fields输出最后一个字段的代码就是```print $NF```

- *当前记录数NR*，number of records

  - ```shell
    #!/usr/bin/awk -f
    #从地100行之后，给每行添加行号
    {
      if( NR > 100){
        print NR, $0;
      }
    }
    #获取行数
    #!/usr/bin/awk -f
    END{
      print NR;
    }
    ```

- *行分割符 RS*: record separator

  - RS=""会将整个文档变成一行
  - RS=" ", 会将每个字段变成一行；输出文中所有单词 `awk 'BEGIN{RS=" "} {print ;}'`

- *行输出分隔符ORS*:  

  - 将unix换行符换成non-unix换行符```awk 'BEGIN{ORS="\r\n"}{print ;}'

- *FILENAME*:  当前正在处理的文件名

##### awk 关联数组  associative array

- 也就是任意string都能当下标，类似map

- ```shell
  #!/usr/bin/awk -f
  BEGIN{
  	username[""]=0;   #to store invalid input such as those has no $3
  }
  {username[$3]++;} 
  END{
  	for(i in username){
  		if(i!=""){
  			print username[i],i
  		}
  	}
  }
  ```

- 不存在多维array，但是可以使用组装下标的形式来实现`a[1","2] ++;`

##### awk print和printf区别

- print 会默认使用OFS作域分割、使用ORS作行分割
- printf 不会使用这些，需手动指定\t \n等，但是可以指定精度、格式化输出

##### awk string函数

- `length(string)`
- `index(string, ch)`
- `substr(string, pos[, length])`
- `n=split(string, array, spliter)` 依照spliter分割string，放到array中(array[1], array[2])，返回个数

##### shell单词统计

```bash
cat *$ |   # 读取所有参数，每个参数是一个文件
tr -cs A-Za-z '\012' |  #-c将A-Za-z 以外的字符全部转换为换行； -s去除重复行
tr A-Z a-z |  #大写转小写
sort |
uniq -c |  #排序后去重复，-c计算每个重复数量
sort -r -n | #-r 逆序排列   -n按值排序
sed 25q   #打印25行后退出
```

```shell
awk 'BEGIN{RS=" "}(NF>0){print}' | tr A-Z a-z | sort | uniq -c | sort -r n | sed 25q
```

##### 检查某命令使用的系统调用

```bash
strace -c -f -S name whoami 2>&1 1>/dev/null | tail -n +3 | head -n -2 | awk '{print $(NF)}'
```

- -c 表示对各个syscall就行相关统计
- -f 表示追踪thread
- -S name 表示sort by name

##### awk使用shell变量，每行前增加日期

```bash
awk -v date="$(date +"%Y%m%d-%H:%M:%S ")" '{print date$0}'
# -v 是变量赋值
# $0 是原行所有内容
```

##### 单引号、双引号

In the C and Bourne shell, the quote is just a switch. It turns the interpretation mode on or off. There is really no such concept as "start of string" and "end of string". **The quotes toggle a switch inside the interpretor**. The quote character is not passed on to the application

- awk 和 shell 和 terminal对于引号的理解不同！所以注意**写脚本**和**执行命令**对引号的使用区别
- "" : awk 不解析里面的内容，shell会解释
- "\t":  awk会识别\t, shell会认为\是转义 
- $: awk是指fields，shell认为是变量
- ''单引号: awk写在shell脚本/terminal中需要用单引号，单引号在shell中不解析，可换行，若无单引号，里面的内容包括双引号等会被shell本身解析。但是单独写awk file，则不需要单引号。

##### 在管道中添加额外的一行

- ```shell
  ls -l | (echo "stat count user group"; cat -) | tr ' ' '	'
  #减号 - 是指从标准输入读取
  ```

##### sort 使用详解

- `sort -t ' ' -k 1 -k 2`         -t指定分隔符  -k 1 先按Fields 1排序，然后按Fields 2排
- `sort -t ',' -k 1n -k 2rn`   1n 列1当作数字排序，然后列2当作数字反向排
- -k `[ FStart [ .CStart ] ][ Modifier ] [ , [ FEnd [ .CEnd ] ][ Modifier ] ]`
  - 起始位置, 结束位置；Modifier是指n r等

### [sed](http://www.grymoire.com/Unix/SedChart.pdf) [-arg] 'address command'

- Stream Editor
- 括号    **`-r`**  表示扩展RegularExpression
  - `\(\)` 在常规sed中实现括号功能，否则当作普通括号
  - `( )`   在扩展-r sed中实现括号功能
- ​

"/proc/self/exe"  取当前进程之静态映像文件的绝对路径

**`timeout duration command`** 超过duration之后还不返回的话，则杀掉command，返回值同原command



##### 测试网络带宽 iperf3



