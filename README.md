# 毛概课堂互动网站

这是“农村包围城市、武装夺取政权”课堂展示的常驻互动网站：

- GitHub Pages 托管前端页面；
- Supabase 保存两轮匿名投票、互动状态并实时同步主持人控制台；
- 同学进入参与页，先完成第一轮判断，阅读补充调查信息后完成第二轮判断；
- 主持人控制台展示两轮票数、两轮参与人数和匿名改选统计。

## 目录

- `index.html`：同学参与页面
- `admin.html`：主持人控制台
- `participant.js`：参与端逻辑
- `admin.js`：主持端逻辑
- `app.js`：Supabase连接、读取状态、实时订阅和统计
- `style.css`：页面样式
- `config.example.js`：前端配置模板
- `supabase/schema.sql`：Supabase数据库表、RLS策略、投票和主持控制函数
- `generate-host-token.mjs`：生成主持人令牌

## 一、你需要做的账号操作

### 1. 创建Supabase项目

1. 登录 Supabase，新建一个项目。
2. 打开项目的 **SQL Editor**。
3. 先在本地运行下面的命令生成一个随机主持人令牌：

```bash
node generate-host-token.mjs
```

4. 复制生成的随机字符串。
5. 打开 `supabase/schema.sql`，把：

```text
CHANGE_ME_LONG_RANDOM_HOST_TOKEN
```

替换成刚才生成的字符串。
6. 将完整的 `supabase/schema.sql` 粘贴到 Supabase SQL Editor 并执行。

如果重复执行SQL，可能会因为已有表或Realtime配置产生冲突；首次部署时执行一次即可。需要重置项目时再单独处理。

### 2. 获取浏览器端配置

在 Supabase 项目中打开：**Project Settings → Data API**（旧界面可能叫 API）。找到：

- **Project URL**
- **Publishable key**，或旧界面的 **anon key**

只需要这两个值。不要使用、不要发送：

- `service_role key`
- Secret key
- 数据库密码
- JWT secret

### 3. 创建前端配置文件

复制配置模板：

```bash
cp config.example.js config.js
```

然后编辑 `config.js`：

```js
window.APP_CONFIG = {
  supabaseUrl: 'https://你的项目编号.supabase.co',
  supabaseAnonKey: '你的_publishable_或_anon_key',
  defaultSessionId: 'main',
  siteTitle: '先判断，再调查，再判断',
};
```

`config.js`需要随着静态网站一起提交到GitHub Pages，因为浏览器必须知道Supabase的项目URL和客户端key。这里的publishable/anon key本来就设计为出现在浏览器端，它不是管理员密钥；安全边界由Supabase的RLS策略和数据库函数完成。绝对不要把`service_role key`、Secret key或数据库密码写入`config.js`。如果只想在本地临时测试，可另存为`config.local.js`；该文件会被`.gitignore`忽略。

### 4. 本地测试

这个项目是静态网页，不能直接用双击HTML的方式测试。可在项目目录运行任意一个本地静态服务器，例如：

```bash
npx serve .
```

或者使用VS Code的Live Server。先打开：

```text
http://localhost:3000/admin.html?session=main&host=你的HOST_TOKEN
```

再用另一个浏览器窗口打开参与页，测试两轮流程。

## 二、发布到GitHub Pages

1. 在GitHub创建一个空仓库，例如 `maogai-class-interaction`。
2. 在本地项目目录执行：

```bash
git init
git add .
git commit -m "Initial classroom interaction site"
git branch -M main
git remote add origin https://github.com/你的用户名/你的仓库名.git
git push -u origin main
```

3. GitHub仓库中打开 **Settings → Pages**。
4. Source选择 **Deploy from a branch**。
5. Branch选择 `main`，目录选择 `/ (root)`，保存。
6. 等待GitHub Pages部署完成，得到类似：

```text
https://你的用户名.github.io/你的仓库名/
```

## 三、正式使用的链接

主持人控制台：

```text
https://你的用户名.github.io/你的仓库名/admin.html?session=main&host=你的HOST_TOKEN
```

同学参与页：主持人控制台会自动生成二维码，二维码指向：

```text
https://你的用户名.github.io/你的仓库名/?session=main
```

不要把带有`host=`的主持人控制台链接发到班级群里。班级只需要看到参与二维码或参与页链接。

## 四、上线前检查清单

- [ ] Supabase SQL执行成功；
- [ ] Supabase Realtime中已启用`session_state`和`votes`表；
- [ ] `config.js`已填写，但没有被Git跟踪；
- [ ] GitHub Pages页面能正常打开；
- [ ] 主持人链接带有正确的`host`令牌；
- [ ] 手机能扫码打开参与页；
- [ ] 第一轮投票能在主持人端实时出现；
- [ ] 公开调查信息后，第二轮能开放；
- [ ] 第二轮结果和改选统计能出现；
- [ ] 正式展示前点击“清空并重置”；
- [ ] 不把`service_role key`、数据库密码或Supabase Secret key提交到GitHub。
