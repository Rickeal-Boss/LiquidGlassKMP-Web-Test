# AndroidLiquidGlass-kmp 原版与 Web 版差异对比

## 概述

原版 `AndroidLiquidGlass-kmp` 是一个 KMP (Kotlin Multiplatform) 项目，支持 Android、Desktop (JVM)、macOS、iOS 平台，但**不支持 Web (JS/WasmJS)**。Web 版在保持原有代码几乎不变的前提下，通过构建配置调整和新增 Web 平台入口文件，成功让项目支持了 Web 平台。

---

## 变更总览

| 类别         | 变更数         | 说明                                                                                     |
| ------------ | -------------- | ---------------------------------------------------------------------------------------- |
| 构建配置文件 | 4 个文件有差异 | settings.gradle.kts、libs.versions.toml、backdrop/build.gradle.kts、app/build.gradle.kts |
| 源代码       | 0 个文件有差异 | backdrop 模块所有源代码完全一致                                                          |
| 新增文件     | 4 个文件       | jsMain 和 wasmJsMain 入口                                                                |
| 修改文件     | 1 个文件       | HomeContent.kt 添加背景色                                                                |
| 移除模块     | 1 个模块       | androidApp 模块不再 include                                                              |

---

## 详细差异分析

### 一、settings.gradle.kts

| 配置项   | 原版                               | Web 版              | 影响                                                         |
| -------- | ---------------------------------- | ------------------- | ------------------------------------------------------------ |
| 仓库模式 | `FAIL_ON_PROJECT_REPOS`            | `PREFER_PROJECT`    | Web 版允许子项目声明自己的仓库（Web 目标可能需要额外依赖源） |
| 包含模块 | `:backdrop`, `:app`, `:androidApp` | `:backdrop`, `:app` | 移除 androidApp 模块，Web 部署不需要 Android 宿主应用        |

**变更原因：** `FAIL_ON_PROJECT_REPOS` 会阻止子模块声明自己的仓库，而 Web 编译可能需要额外的依赖仓库。`PREFER_PROJECT` 给予子模块更大的灵活性。移除 `androidApp` 模块是因为 Web 部署不需要 Android 宿主工程。

---

### 二、gradle/libs.versions.toml

版本号降低（降级），这是一个关键差异：

| 依赖                        | 原版   | Web 版 | 变更 |
| --------------------------- | ------ | ------ | ---- |
| AGP (Android Gradle Plugin) | 9.3.0  | 9.2.1  | 降级 |
| Kotlin                      | 2.4.10 | 2.3.21 | 降级 |
| AndroidX Core               | 1.19.0 | 1.18.0 | 降级 |
| Compose Multiplatform       | 1.11.1 | 1.11.0 | 降级 |

**变更原因：** 这是 Web 支持的关键。较新版本的 Kotlin/Compose Multiplatform 可能存在 Web 目标的兼容性问题或尚未稳定。AI 将版本降级到了经过验证的、对 Web 支持更稳定的版本组合。Kotlin 2.3.x + Compose 1.11.0 是 Web/Wasm 目标上经过更多测试的版本组合。

---

### 三、backdrop/build.gradle.kts（核心库模块）

这是最关键的变更，直接决定了 `backdrop` 库能否编译到 Web 平台。

#### 3.1 移除 `applyDefaultHierarchyTemplate()`

```diff
- applyDefaultHierarchyTemplate()
```

**变更原因：** `applyDefaultHierarchyTemplate()` 是 Kotlin 1.9.20+ 引入的默认层级模板，它会自动为 source sets 建立依赖关系。但在某些版本组合中，默认模板对 Web 目标（js/wasmJs）的 source set 关联可能不正确或不够灵活。手动显式声明 source set 依赖关系可以更精确地控制 Web 平台的编译配置。

#### 3.2 Source Set 声明方式变更

原版使用 `getByName()` 直接获取（依赖默认模板自动创建），Web 版使用 `by getting` / `by creating` 显式声明：

```diff
// 原版
- val commonMain = getByName("commonMain") { ... }
- val skikoMain = create("skikoMain") { ... }
- val iosMain = getByName("iosMain") { ... }

// Web 版
+ val commonMain by getting { ... }
+ val skikoMain by creating { ... }
+ val iosMain by creating { ... }
```

关键差异：`iosMain` 从 `getByName`（依赖默认模板创建）变为 `by creating`（手动创建），避免默认模板自动创建可能带来的 source set 层级冲突。

#### 3.3 JS 目标声明方式变更

```diff
- js {
+ js(IR) {
      browser()
  }
```

**变更原因：** `js(IR)` 显式指定使用 IR 编译器后端（而非旧的 LEGACY 后端）。在 Kotlin 2.x 中，IR 是唯一可用的 JS 后端，但显式声明可以避免某些版本兼容性警告。

#### 3.4 新增 `ContextParameters` 语言特性

```diff
+ all {
+     languageSettings.enableLanguageFeature("ContextParameters")
+ }
```

**变更原因：** 项目中可能使用了 Kotlin `context parameters` 特性（Kotlin 2.1+ 的实验性特性）。在某些版本中，这个特性需要在所有 source set 中显式启用才能通过 Web 目标的编译。

#### 3.5 更明确的 source set 依赖链

Web 版对 `iosMain`、`iosArm64Main`、`iosSimulatorArm64Main` 的依赖关系声明更加明确：

```diff
  val iosMain by creating {
      dependsOn(skikoMain)
  }
- val iosArm64Main = getByName("iosArm64Main") { }
- val iosSimulatorArm64Main = getByName("iosSimulatorArm64Main") { }
+ val iosArm64Main by getting {
+     dependsOn(iosMain)
+ }
+ val iosSimulatorArm64Main by getting {
+     dependsOn(iosMain)
+ }
```

---

### 四、app/build.gradle.kts（演示应用模块）

#### 4.1 移除 `applyDefaultHierarchyTemplate()`

与 backdrop 模块相同，移除默认层级模板，改为手动显式声明 source set 依赖。

#### 4.2 JS/WasmJS 目标配置增强

这是让 app 模块能在 Web 上运行的核心变更：

```diff
  js(IR) {
-     browser()
+     browser {
+         commonWebpackConfig {
+             outputFileName = "composeApp.js"
+         }
+     }
+     binaries.executable()
  }
  wasmJs {
-     browser()
+     browser {
+         commonWebpackConfig {
+             outputFileName = "composeApp.js"
+         }
+     }
+     binaries.executable()
  }
```

- **`binaries.executable()`**：将 JS/WasmJS 编译目标标记为可执行（而非仅库），生成可独立运行的 JS 文件。
- **`commonWebpackConfig { outputFileName = "composeApp.js" }`**：指定 Webpack 打包后的输出文件名，与 HTML 页面中引用的脚本名一致。

#### 4.3 移除 `-Xlambdas=class` 编译器参数

```diff
- freeCompilerArgs.addAll("-Xlambdas=class")
```

**变更原因：** `-Xlambdas=class` 会将所有 lambda 编译为匿名类，这在 Android 上可能有助于避免某些性能问题，但可能与 Web 目标的 IR 编译器不兼容。移除后使用默认的 lambda 编译策略。

#### 4.4 Source Set 依赖声明更明确

与 backdrop 模块类似，Web 版对所有 source set 的依赖关系进行了显式声明，避免默认模板自动创建可能带来的问题。

---

### 五、新增文件：Web 平台入口

#### 5.1 jsMain/kotlin/.../Main.js.kt

```kotlin
package com.kyant.backdrop.catalog

import androidx.compose.ui.ExperimentalComposeUiApi
import androidx.compose.ui.window.ComposeViewport

@OptIn(ExperimentalComposeUiApi::class)
fun main() {
    ComposeViewport(viewportContainerId = "composeApp") {
        MainContent()
    }
}
```

**作用：** JS 平台的入口函数，使用 `ComposeViewport` 将 Compose UI 渲染到 HTML 页面中 ID 为 `composeApp` 的 DOM 容器中。

#### 5.2 jsMain/resources/index.html

```html
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="UTF-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <title>Liquid Glass</title>
    <style>
      * {
        margin: 0;
        padding: 0;
        box-sizing: border-box;
      }
      html,
      body {
        width: 100%;
        height: 100%;
        overflow: hidden;
        background: black;
      }
      #composeApp {
        width: 100%;
        height: 100%;
      }
    </style>
  </head>
  <body>
    <div id="composeApp"></div>
    <script src="composeApp.js"></script>
  </body>
</html>
```

**作用：** HTML 壳页面，黑色背景 + 全屏 Compose 容器，确保 Web 端有正确的渲染环境。

#### 5.3 wasmJsMain/ 下的文件

与 `jsMain/` 内容完全相同，为 WasmJS (WebAssembly) 目标提供相同的入口。

---

### 六、修改的源代码：HomeContent.kt

```diff
+ import androidx.compose.foundation.background

  // 在 HomeContent 中添加：
+ val backgroundColor = if (isLightTheme) Color.White else Color.Black

  Column(
-     modifier = modifier.verticalScroll(rememberScrollState())
+     modifier = modifier.background(backgroundColor).verticalScroll(rememberScrollState())
  )
```

**变更原因：** 在 Web 环境中，Canvas/Compose 层默认可能是透明的，导致内容不可见。添加明确的背景色确保页面在 Web 浏览器中有正确的视觉呈现。

---

### 七、backdrop 模块源代码：完全无变更

`backdrop/src` 下的所有源代码（包括 commonMain、androidMain、skikoMain 中的所有 Kotlin 文件）**100% 一致**，没有任何修改。这说明原版 `backdrop` 库的代码本身是**平台无关的**，已经可以在 Web 上编译，只是构建配置没有启用 Web 目标。

---

## 总结：做了什么让原版支持 Web？

核心思路是 **"调整构建配置 + 新增 Web 入口文件"**，而非修改任何库代码：

1. **版本降级**：将 Kotlin 2.4.10 → 2.3.21、Compose 1.11.1 → 1.11.0，使用对 Web 目标更稳定的版本组合。
2. **移除默认层级模板**：`applyDefaultHierarchyTemplate()` 在 Web 目标上可能产生不正确的 source set 关联，改为手动显式声明所有依赖关系。
3. **启用 JS/WasmJS 可执行目标**：在 `app/build.gradle.kts` 中为 JS 和 WasmJS 目标添加 `binaries.executable()` 和 Webpack 输出配置。
4. **新增 Web 入口文件**：为 `jsMain` 和 `wasmJsMain` 创建 `ComposeViewport` 入口和 HTML 页面。
5. **修复 Web 显示问题**：在 `HomeContent.kt` 中添加背景色，避免 Web 端透明背景导致的显示异常。
6. **移除 Android 宿主模块**：不再 include `androidApp`，因为 Web 部署不需要它。
7. **仓库模式调整**：`FAIL_ON_PROJECT_REPOS` → `PREFER_PROJECT`，给子模块更大的依赖灵活性。
8. **移除不兼容的编译器参数**：去掉 `-Xlambdas=class`，避免与 Web IR 编译器冲突。

**关键发现：** backdrop 库的源代码本身已经是跨平台的，不需要任何修改就能在 Web 上运行。Web 支持的工作完全在构建配置层面。
