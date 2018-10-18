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

也可以使用以下的命令直接完成应用的构建和发布:

```bash
oc new-app openshift/s2i-react-nginx~https://git.liandisys.com.cn/hz/ant-design-pro.git
```

## 不足

 * 最终Image包含Node.JS/Yarn的Package, 镜像Size大约为540M, 不够精简。如果用Multi-Stage方式选择类似alpine作为最终的Base Image的话可以大大降低容器的尺寸。
 * 使用本S2I Builder进行yarn构建时需要下载所有的依赖包，耗时较多, 可以在S2I Builder构建时增加下载依赖包的过程提速。
