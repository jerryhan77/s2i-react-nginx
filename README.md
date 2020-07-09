Source To Image React-Nginx
=====================

This repository contains the source for creating a
[source-to-image](https://github.com/openshift/source-to-image) builder image,
which can be used to create reproducible Docker images from your static directory's
source code served by nginx. The resulting image can be run using [Docker](https://docker.com).

For more information about using these images with OpenShift, please see the official
[OpenShift Documentation](https://docs.openshift.org/latest/using_images/s2i_images/php.html).

本项目为OpenShift提供Node.JS/React应用的S2I构建Image, 基于[https://github.com/bigdelivery/s2i-create-react-app.git](https://github.com/bigdelivery/s2i-create-react-app.git)

 * 支持NodeJS 8
 * 采用Yarn进行Build
 * Build产生的静态内容，由Nginx作为Web Server

在OpenShift 3.7/3.10环境测试通过。

## 使用方法

### 创建定制的Node.JS/React的S2I Builder

使用下面的命令在当前项目空间创建Image/ImageStream:

```bash
oc new-build https://git.liandisys.com.cn/hz/s2i-react-nginx.git --strategy=docker
```

也可以在openshift公共区创建，以便多个项目共用:

```bash
oc new-build https://git.liandisys.com.cn/hz/s2i-react-nginx.git --strategy=docker -n openshift
```

目前zeus环境已经在OpenShift公共区构建了本S2I Builder Image, 可以直接使用。

项目可以本项目为蓝本进行定制修改。

### 使用之前创建的S2I Builder构建应用镜像


```bash
oc new-build https://git.liandisys.com.cn/hz/ant-design-pro.git --strategy=source --image-stream=s2i-react-nginx:latest
oc new-build https://git.liandisys.com.cn/hz/antd-admin.git#ocp-4.3.9 --strategy=source --image-stream=s2i-react-nginx:latest
```

也可以直接使用已经在公共区创建的S2I Builder构建Node.JS应用:

```bash
oc new-build https://git.liandisys.com.cn/hz/ant-design-pro.git --strategy=source --image-stream=openshift/s2i-react-nginx:latest
oc new-build https://git.liandisys.com.cn/hz/antd-admin.git#ocp-4.3.9 --strategy=source --image-stream=openshift/s2i-react-nginx:latest
```

应用的镜像构建成功后就可以将应用发布了。

当然，也可以使用以下的命令直接完成应用的构建和发布:

```bash
oc new-app openshift/s2i-react-nginx~https://git.liandisys.com.cn/hz/ant-design-pro.git
```

为了提高NodeJS的构建速度，可以在BC中添加环境变量(`NPM_CONFIG_REGISTRY=https://registry.npm.taobao.org`)，指定使用国内的源。

## 不足

 * 最终Image包含Node.JS/Yarn的Package, 镜像Size大约为540M, 不够精简。如果用Multi-Stage方式选择类似alpine作为最终的Base Image的话可以大大降低容器的尺寸。
 * 使用本S2I Builder进行yarn构建时需要下载所有的依赖包，耗时较多, 可以在S2I Builder构建时增加下载依赖包的过程提速。

### Openshift Chain-Build

针对上述的不足，为了尽可能减少Runtime Image的大小，可以使用OpenShift的Chain-Build功能，将整个应用的构建过程分为两个Stage：
 1. 使用s2i-react-nginx作为Builder，构建出包含有Node.JS编译结果-静态HTML文件的Docker映像
 2. 新建一个Docker Build，在Dockerfile设置为从上一步产生的Image中，将编译结果文件复制到另外一个只含有运行环境Image，从而获得最终用于发布的Docker映像

以前面的应用为例，ant-design-pro:latest已经包含了NodeJS的编译结果，但我们并不用它发布应用。

选择哪个Runtime Image呢？

 * `centos/httpd-24-centos7:latest` - OpenShift提供的基于CentOS 7的原生apache 2.4镜像，还不够精练。
 * `bitnami/apache:latest` - 可以在OpenShift中使用，比上一个小一些。但是特别要小心，如果Docker Storage Driver为Overlay的环境会运行失败。

下面这个BuildConfig采用`centos/httpd-24-centos7:latest`作为Runtime - image-build.yml：

```
apiVersion: v1
kind: BuildConfig
metadata:
  name: image-build
spec:
  output:
    to:
      kind: ImageStreamTag
      name: image-build:latest
  source:
    type: Dockerfile
    dockerfile: |-
      FROM httpd:latest
      COPY ./src/ /tmp/src/
      RUN /usr/libexec/s2i/assemble
    images:
    - from: 
        kind: ImageStreamTag
        name: ant-design-pro:latest
      paths: 
      - sourcePath: /opt/app-root/src/
        destinationDir: "."
  strategy:
    dockerStrategy:
      from: 
        kind: ImageStreamTag
        name: httpd:latest
        namespace: openshift
    type: Docker
  triggers:
  - imageChange: {}
    type: ImageChange
```

如果环境许可，也可以使用下面采用`bitnami/apache:latest`作为Runtime的BuildConfig - image-build.yml：

```
apiVersion: v1
kind: BuildConfig
metadata:
  name: image-build
spec:
  output:
    to:
      kind: ImageStreamTag
      name: image-build:latest
  source:
    type: Dockerfile
    dockerfile: |-
      FROM apache:latest
      COPY ./src/ /opt/bitnami/apache/htdocs/
    images:
    - from: 
        kind: ImageStreamTag
        name: ant-design-pro:latest
      paths: 
      - sourcePath: /opt/app-root/src/
        destinationDir: "."
  strategy:
    dockerStrategy:
      from: 
        kind: ImageStreamTag
        name: apache:latest
    type: Docker
  triggers:
  - imageChange: {}
    type: ImageChange
```

使用以下命令创建本BC及相关的ImageStream：
```
oc create is apache
oc create imagestreamtag apache:latest --from-image=docker.io/bitnami/apache:latest
oc create is image-build
oc create imagestreamtag image-build:latest
oc create -f image-build.yml
```

如果Build成功，就可以用image-build:latest发布应用了。

让我们比较一下采用不同Build策略获得的Runtime Image大小差别:

| Base Image | Size (MiB) | Size in WebConsole (MiB) |
|----------|----------|----------|
| s2i-react-nginx | 543 | 192.8 |
| centos/httpd-24-centos7:latest | 362 | 133.8 |
| bitnami/apache:latest | 162 | 62.7 |

很明显，用Chain-Build大幅消减了最终Runtime Image的大小，如果采用alpine的Image作为Base，还能更小。

不过，Alpine的Image不太适合在Openshift中使用，有精力的话可以以此为基础构建一个更小的镜像。
