import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some, from_result}
import gleam/string

// 概念图谱的数据层。
//
// 类型即校验：字段缺失或拼错，编译不过。引用完整性（超边指向不存在的概念）、
// 题号覆盖与 cells 完整性由 test/concepts_test.gleam 兜住，不另设构建期校验层。
//
// 本文件是全课的内容索引：六簇 98 个概念、85 条关系（17 条结构超边 + 68 条二元边）、
// 67 道课后习题全覆盖。
// 一个概念只在这里定义一次，其余地方（mdbook 页面、静态总表、画布）都从这里取。
// 机制只写在节点里，故事只写在讲义里，同一段机制不在两处各写一遍。
//
// 写作约束沿用 docs/course-ui.md §3.5：不复述课件、清单必须带机制或量纲、
// 默认读者要考试（每个字段都要能直接当答案用）。

pub type Cluster {
  Intro
  Basics
  Architecture
  Network
  Platform
  Security
}

pub type QuestionRef {
  QuestionRef(chapter: Int, item: Int)
}

pub type Concept {
  Concept(
    id: String,
    name: String,
    aliases: List(String),
    cluster: Cluster,
    def: String,
    mechanism: String,
    caliber: String,
    questions: List(QuestionRef),
    chapter: String,
  )
}

pub type EdgeKind {
  Matrix
  Selection
  Evolution
  Mapping
  Flow
  IsA
  PartOf
  Requires
  Refines
  Measures
  Contrasts
}

pub type Role {
  Role(name: String, members: List(String))
}

// 超边的一格：行标签、列标签、格子里的内容。
// 矩阵型与选型型超边都靠它落成侧栏里的表格；没有 cells 的超边退回角色清单。
pub type Cell {
  Cell(row: String, col: String, text: String)
}

pub type Hyperedge {
  Hyperedge(
    id: String,
    kind: EdgeKind,
    label: String,
    roles: List(Role),
    result: Option(String),
    cells: List(Cell),
    note: String,
  )
}

pub type Graph {
  Graph(concepts: List(Concept), hyperedges: List(Hyperedge))
}

// 簇 ---------------------------------------------------------------------

pub fn all_clusters() -> List(Cluster) {
  [Intro, Basics, Architecture, Network, Platform, Security]
}

pub fn cluster_ids() -> List(String) {
  all_clusters() |> list.map(cluster_id)
}

pub fn cluster_id(cluster: Cluster) -> String {
  case cluster {
    Intro -> "intro"
    Basics -> "basics"
    Architecture -> "architecture"
    Network -> "network"
    Platform -> "platform"
    Security -> "security"
  }
}

pub fn cluster_label(cluster: Cluster) -> String {
  case cluster {
    Intro -> "概念"
    Basics -> "基础"
    Architecture -> "架构"
    Network -> "网络"
    Platform -> "平台"
    Security -> "安全"
  }
}

pub fn edge_kind_label(kind: EdgeKind) -> String {
  case kind {
    Matrix -> "矩阵"
    Selection -> "选型"
    Evolution -> "演进"
    Mapping -> "映射"
    Flow -> "流程"
    IsA -> "上位"
    PartOf -> "组成"
    Requires -> "依赖"
    Refines -> "细化"
    Measures -> "度量"
    Contrasts -> "对照"
  }
}

// 二元边画成一条线，其余超边画成菱形节点再连向成员。
pub fn is_binary(edge: Hyperedge) -> Bool {
  case edge.kind {
    IsA | PartOf | Requires | Refines | Measures | Contrasts -> True
    _ -> False
  }
}

fn role_names(kind: EdgeKind) -> #(String, String) {
  case kind {
    IsA -> #("下位", "上位")
    PartOf -> #("部分", "整体")
    Requires -> #("依赖方", "被依赖")
    Refines -> #("细化", "被细化")
    Measures -> #("度量", "被度量")
    Contrasts -> #("对照方", "对照对象")
    _ -> #("主体", "对象")
  }
}

// 题号 -------------------------------------------------------------------

pub fn question_id(question: QuestionRef) -> String {
  int.to_string(question.chapter) <> "-" <> int.to_string(question.item)
}

pub fn question_label(question: QuestionRef) -> String {
  "第"
  <> int.to_string(question.chapter)
  <> "章习题 "
  <> int.to_string(question.item)
}

// 章节页：第 1—6 章的文件名带前导零，第零章另有命名。
pub fn question_href(question: QuestionRef) -> String {
  case question.chapter {
    0 -> "ch00-工厂速写.html"
    n if n < 10 -> "ch0" <> int.to_string(n) <> ".html"
    n -> "ch" <> int.to_string(n) <> ".html"
  }
}

// 图 ---------------------------------------------------------------------

pub fn graph() -> Graph {
  Graph(concepts: concepts(), hyperedges: hyperedges())
}

// 概念 -------------------------------------------------------------------
//
// 顺序即画布上的行序：簇内按叙事从总到分排列，不按拼音、不按课件页序。

fn concepts() -> List(Concept) {
  [
    // 概念 ---------------------------------------------------------------
    Concept(
      id: "industrial-internet",
      name: "工业互联网",
      aliases: ["工业互联网（AII 定义）", "新型基础设施"],
      cluster: Intro,
      def: "新一代信息通信技术与工业经济深度融合的新型基础设施、应用模式和工业生态。",
      mechanism: "AII 定义拆四件：三个身份（新型基础设施、应用模式、工业生态）分别对应政府与运营商、平台厂商、联盟三类主体；一个动作是全面连接人、机、物、系统；两个覆盖是全产业链与全价值链；三个方向是数字化、网络化、智能化。",
      caliber: "GE 2012 的技术视角定义是「开放的、全球化的网络，把人和数据、机器连接起来」，一个讲连什么、一个讲经济属性。",
      questions: [QuestionRef(1, 1), QuestionRef(1, 2)],
      chapter: "ch01.html",
    ),
    Concept(
      id: "ii-essence",
      name: "本质与核心（四跨）",
      aliases: ["四跨", "跨设备跨系统跨厂区跨地区"],
      cluster: Intro,
      def: "通过开放的、全球化的工业级网络平台，把设备、生产线、工厂、供应商、产品和客户连接融合，共享工业经济中的要素资源。",
      mechanism: "结果形态是跨设备、跨系统、跨厂区、跨地区的互联互通。每跨一次，数据都要带着完整语义过去；难点在对岸拿到的数还是那个意思，单点采集解决不了。",
      caliber: "",
      questions: [QuestionRef(1, 4)],
      chapter: "ch01.html",
    ),
    Concept(
      id: "ii-features",
      name: "三大特点（低时延·高可靠·广覆盖）",
      aliases: ["低时延高可靠广覆盖"],
      cluster: Intro,
      def: "工业互联网对网络的三项要求：低时延、高可靠、广覆盖。",
      mechanism: "低时延要的是时延上界与抖动可预期，闭环控制必须在一个控制周期内走完采样—计算—执行，时延超过周期，执行机构就作用在过时状态上；高可靠要写成可用性指标与 SLA，靠冗余、断点续传、故障可观测；广覆盖靠无线补位，AGV 与偏远井场拉不了线。",
      caliber: "",
      questions: [],
      chapter: "ch01.html",
    ),
    Concept(
      id: "ii-vs-internet",
      name: "与传统互联网的四点区别",
      aliases: ["四点区别"],
      cluster: Intro,
      def: "按服务主体、网络形态、复杂程度与发展模式、市场格局四栏区分传统互联网与工业互联网。",
      mechanism: "四栏的判据依次是连接对象是谁、网归谁管且能不能接受中断、一套方案能不能卖所有厂、会不会赢家通吃；结论是工业侧垂直细分、难出寡头、仍处起步阶段。",
      caliber: "",
      questions: [QuestionRef(1, 5)],
      chapter: "ch01.html",
    ),
    Concept(
      id: "ii-status",
      name: "我国发展成果（四方向）",
      aliases: ["东西南北中", "国家顶级节点"],
      cluster: Intro,
      def: "我国工业互联网在网络、标识解析、平台、安全四个方向的阶段性成果。",
      mechanism: "网络侧企业外网引入 5G 与 SDN，运营商推出面向产业的专网；标识解析形成「东西南北中」服务架构；平台数百家，重点平台平均设备连接近 60 万台、平均工业 App 超 1500 个；安全侧以集成创新方向支持创新工程项目、遴选试点示范。",
      caliber: "国家顶级节点：第一章记北京、上海、重庆、广州、武汉 5 城，第四章列 7 城（另加南京、成都），引用时以所用章节为准。",
      questions: [QuestionRef(1, 12)],
      chapter: "ch01.html",
    ),
    Concept(
      id: "internet-vs-web",
      name: "互联网与万维网",
      aliases: ["万维网", "ARPANET"],
      cluster: Intro,
      def: "互联网是全球计算机互联的网络，1969 年由 ARPANET 起家；万维网是建立在互联网之上的信息服务系统。",
      mechanism: "万维网只是互联网上的一项服务：接入网线叫上网，打开网页才用到万维网。区分它们是为了说清承载与服务两层关系。",
      caliber: "",
      questions: [],
      chapter: "ch01.html",
    ),
    Concept(
      id: "three-stages",
      name: "数字化—网络化—智能化",
      aliases: ["新一代智能制造三阶段", "数字化网络化智能化"],
      cluster: Intro,
      def: "新一代智能制造的三个阶段：数字化制造、数字化网络化制造、数字化网络化智能化制造，特性是阶段性、延续性、融合性。",
      mechanism: "数字化对应单点优化，网络化对应全面互联，智能化对应全局智能；每一阶段都建立在前一阶段的数据与连接之上，所以不能跳级。",
      caliber: "课件用四次工业革命（蒸汽、电气化、信息化、新工业革命）交代背景，只需记这条三阶段线。",
      questions: [],
      chapter: "ch01.html",
    ),
    Concept(
      id: "iot",
      name: "物联网",
      aliases: ["IoT"],
      cluster: Intro,
      def: "基于互联网、传统电信网等的信息承载体，通过信息感知装置实时采集物体或过程信息，经网络接入实现物与物、物与人的泛在连接。",
      mechanism: "本质仍是互联网，终端从计算机扩展到经传感设备接入的物体，所以它继承互联网的协议栈，也继承地址、语义、时延三个问题。「能够被独立寻址」是它和普通传感器的分界。",
      caliber: "被称为继计算机、互联网之后信息产业的第三次浪潮，第二章也写作「第三次革命」。",
      questions: [QuestionRef(1, 8)],
      chapter: "ch01.html",
    ),
    Concept(
      id: "iiot",
      name: "工业物联网",
      aliases: ["IIoT"],
      cluster: Intro,
      def: "通过工业资源的网络互联、数据互通和系统互操作，实现制造资源灵活配置、制造过程按需执行、制造工艺合理优化、制造环境快速适应，构建服务驱动型的新工业体系。",
      mechanism: "与传统物联网的三条判据：感知上要提升设备效率与企业生产率，应用上服务生产、资产价值与运行安全要求更高，设施上建立在既有工业基础设施之上做增量。",
      caliber: "课件同时给出两句：工业物联网是工业互联网的同义词，又与工业互联网存在包含关系——功能范围上同义，体系边界上包含。",
      questions: [QuestionRef(1, 6), QuestionRef(1, 7), QuestionRef(1, 9)],
      chapter: "ch01.html",
    ),
    Concept(
      id: "iiot-six",
      name: "工业物联网六大典型特征",
      aliases: ["六大特征"],
      cluster: Intro,
      def: "智能感知、泛在连通、数字建模、实时分析、精准控制、迭代优化，六者是一条能力链。",
      mechanism: "六项依次是基础、前提、方法、手段、目的、效果。分水岭在第五环精准控制：要写指令、改参数，也就有人为后果负责，所以很多预测性维护卡在第四到第五环之间。",
      caliber: "",
      questions: [],
      chapter: "ch01.html",
    ),
    Concept(
      id: "smart-manufacturing",
      name: "智能制造",
      aliases: ["工业互联网与智能制造的关系"],
      cluster: Intro,
      def: "工业互联网是智能制造的依托基础，智能制造是工业互联网的最终目标。",
      mechanism: "应用范围不同：工业互联网帮助企业上云、提供定制化服务，侧重工业服务，是智能制造的发展模式与现实途径；智能制造面向整个制造价值链的智能化，侧重工业制造。",
      caliber: "",
      questions: [QuestionRef(1, 10), QuestionRef(1, 11)],
      chapter: "ch01.html",
    ),

    // 基础 ---------------------------------------------------------------
    Concept(
      id: "iot-architecture",
      name: "物联网三层架构",
      aliases: ["感知层·网络层·应用层", "物联网四项关键技术"],
      cluster: Basics,
      def: "物联网按感知层、网络层、应用层三层组织，分别对应全面感知、可靠传输、智能处理。",
      mechanism: "三层按采集—传输—处理切；四项关键技术沿同一条链排开：传感器技术（感知输入端）、无线传感技术（末端组网回传）、云计算技术（存算底座）、安全与隐私技术（贯穿三段）。",
      caliber: "",
      questions: [QuestionRef(1, 8), QuestionRef(2, 1), QuestionRef(2, 2)],
      chapter: "ch02.html",
    ),
    Concept(
      id: "sensing-layer",
      name: "感知层",
      aliases: [],
      cluster: Basics,
      def: "物联网三层中最基础、最核心的一层，负责状态的获取与辨识。",
      mechanism: "两类设备分工：各类传感器感知物理量，识别设备（二维码、RFID 标签与读写器）给物体贴标签。两者合起来才回答「是多少」与「是哪一个」。",
      caliber: "",
      questions: [QuestionRef(2, 1)],
      chapter: "ch02.html",
    ),
    Concept(
      id: "network-layer",
      name: "网络层",
      aliases: [],
      cluster: Basics,
      def: "物联网三层中的中枢，承上启下，解决感知层所获数据在一定范围、一定时间内的传输。",
      mechanism: "以长距离传输为主，不关心数据代表什么，只保证准确高效送达。这是刻意解耦：语义交给应用层，同一张传输网才能同时承载多种业务，不必随业务改造。",
      caliber: "",
      questions: [QuestionRef(2, 1), QuestionRef(2, 3)],
      chapter: "ch02.html",
    ),
    Concept(
      id: "application-layer",
      name: "应用层",
      aliases: [],
      cluster: Basics,
      def: "物联网三层中的最顶层，解决信息处理与人机交互。",
      mechanism: "含数据与应用两方面：应用基础设施（云计算、大数据分析平台）负责存储与处理，行业应用服务负责交付；云与大数据在这里落到具体业务。",
      caliber: "",
      questions: [QuestionRef(2, 1)],
      chapter: "ch02.html",
    ),
    Concept(
      id: "sensor",
      name: "传感器",
      aliases: ["敏感元件", "转换元件"],
      cluster: Basics,
      def: "把温度、振动、位移等非电量转换成电学量的装置，由敏感元件、转换元件、转换电路组成，有时另加辅助电源。",
      mechanism: "采集卡与 PLC 模拟输入通道只能读电学量，非电量必须先转成电压、电流或电荷量。分类有三个维度：按被测量、按工作原理、按输出信号；同一只传感器可同时落在三个维度上，所以分类前要先声明按哪个维度。",
      caliber: "",
      questions: [QuestionRef(5, 4)],
      chapter: "ch02.html",
    ),
    Concept(
      id: "wsn",
      name: "无线传感器网络",
      aliases: ["WSN"],
      cluster: Basics,
      def: "部署在监测区域的微型传感器节点自组织构成的网络，节点协同感知并借网关接入公用网络。",
      mechanism: "价值在容错：多节点失效后，其余节点自行挑选路径重建网络，数据回传不因单点故障中断；代价是节点供电与带宽都受限，所以要在本地做聚合再回传。",
      caliber: "",
      questions: [],
      chapter: "ch02.html",
    ),
    Concept(
      id: "fieldbus",
      name: "现场总线",
      aliases: ["FCS", "现场总线控制系统"],
      cluster: Basics,
      def: "应用于生产现场，在现场设备之间、现场设备与控制装置之间实行双向、串行、多结点通信的数字通信技术。",
      mechanism: "本质六项：现场通信网络、现场设备互联、互操作性、分散功能块、通信线供电、开放式互联网络。分散功能块把控制逻辑下放到现场仪表执行、控制站变成虚拟概念，通信线供电让防爆区不必另拉电源线，这两项是它相对 DCS 的实质改动。确定性来自共享介质上的受控访问（主从轮询或令牌），扫描周期可预期，代价是带宽低。",
      caliber: "工业总线按接入对象分三类：传感器级、设备级、现场总线。",
      questions: [QuestionRef(2, 4), QuestionRef(4, 8)],
      chapter: "ch02.html",
    ),
    Concept(
      id: "industrial-ethernet",
      name: "工业以太网",
      aliases: [],
      cluster: Basics,
      def: "基于标准以太网技术、针对工业环境与工业应用做过优化的网络通信技术。",
      mechanism: "标准以太网的 CSMA/CD 冲突后随机退避重发，时延不可界；进现场必须用交换式全双工消除冲突、划分实时通道、按优先级或时间调度排队，把尽力而为改成可预期。",
      caliber: "与现场总线是并列的两大技术体系，判据是是否沿用标准以太网的帧格式与物理层。",
      questions: [QuestionRef(4, 8)],
      chapter: "ch02.html",
    ),
    Concept(
      id: "ie-protocols",
      name: "四种工业以太网协议",
      aliases: ["Modbus TCP", "EtherNet/IP", "EtherCAT", "Profinet"],
      cluster: Basics,
      def: "Modbus TCP/IP、EtherNet/IP、EtherCAT、Profinet 四种主流工业以太网协议。",
      mechanism: "判据只有一条：实时机制怎么实现。Modbus TCP 把报文塞进 TCP 载荷，简单、开销小，缺实时同步与时钟；EtherNet/IP 四层都用标准以太网，节点数不受轮询周期限制；EtherCAT 从机在报文帧穿过时取自己的数并就地插入，一帧服务全部节点，实时性最高；Profinet 用集成在设备里的交换机把 Profibus 的 I/O 通信扩到以太网，复用既有组态与工程量。",
      caliber: "",
      questions: [],
      chapter: "ch02.html",
    ),
    Concept(
      id: "latency",
      name: "时延",
      aliases: ["端到端时延", "抖动"],
      cluster: Basics,
      def: "一个事件从发生到被反馈执行所经过的时间，端到端由采集与编码、排队与调度、传输、处理与执行四段相加。",
      mechanism: "传输段可以算：串行化时延 = 帧长 ÷ 速率（800 bit 在 10 Mbit/s 上是 0.08 ms，在 50 kbit/s 的 LoRa 上是 16 ms），传播时延 = 距离 ÷ 介质速度（光纤约 5 μs/km，空气约 3.3 μs/km）。控制回路看最坏情况：时延上界必须小于控制周期，抖动（相邻包时延之差）比平均值更要命——平均 5 ms、偶尔 80 ms 的链路不能做插补闭环。",
      caliber: "课件「低延迟」与「低时延」是同一个词的两种译法，差别在数量级：4G 是十毫秒，5G uRLLC 是 1 ms。",
      questions: [],
      chapter: "ch02.html",
    ),
    Concept(
      id: "bandwidth",
      name: "带宽",
      aliases: ["峰值速率"],
      cluster: Basics,
      def: "单位时间能通过的比特数，单位 bit/s。",
      mechanism: "只在串行化那一段影响时延：链路排队 30 ms 时，1 Gbit/s 也不比百兆快。需求由采样决定：3 轴振动 × 25.6 kHz × 16 bit ≈ 1.2 Mbit/s 每台，100 台就是 120 Mbit/s；而 OEE 每分钟几个计数，几 kbit/s 就够。",
      caliber: "",
      questions: [],
      chapter: "ch02.html",
    ),
    Concept(
      id: "connection-density",
      name: "连接密度",
      aliases: ["大连接"],
      cluster: Basics,
      def: "单位面积可同时接入的终端数，单位台/km²。",
      mechanism: "与每台终端占用的空口资源成反比：包越小、发得越稀、速率越低，同样频谱挂的终端越多。5G mMTC 的 10⁶ 台/km² 指同一时刻能服务的连接数，LPWAN 的大连接指一个基站能登记的终端数，后者多数时间在休眠。",
      caliber: "",
      questions: [],
      chapter: "ch02.html",
    ),
    Concept(
      id: "power-budget",
      name: "功耗与续航",
      aliases: ["占空比"],
      cluster: Basics,
      def: "续航 ≈ 电池容量 ÷ 平均电流，平均电流 ≈ 发射电流 × 占空比 + 待机电流。",
      mechanism: "发射一次 50 mA、每天 4 次、每次 0.1 s，占空比约万分之一，平均电流才降到 μA 级、才有十年电池；提高上报频率、加下行确认、加定位都会成倍抬高占空比。低功耗来自业务模型允许你少说话。",
      caliber: "",
      questions: [],
      chapter: "ch02.html",
    ),
    Concept(
      id: "5g",
      name: "第五代移动通信（5G）",
      aliases: ["eMBB", "uRLLC", "mMTC"],
      cluster: Basics,
      def: "三个场景：eMBB（增强移动宽带）、uRLLC（低时延高可靠）、mMTC（海量机器类通信）。",
      mechanism: "三个场景差在瓶颈：uRLLC 卡时延与可靠性（单向 1 ms、丢包 10⁻⁵），eMBB 卡带宽（峰值 1 Gbit/s），mMTC 卡连接密度（10⁶ 台/km²）。把三种业务放进一张网靠网络切片，把同一套物理资源切成互相隔离的逻辑网；再把用户面下沉到工厂侧靠边缘计算，避免回传绕行。",
      caliber: "五项指标各有口径：1 ms 是空口单向用户面时延、不含跨地域回传；99.9999% 与 1 ms 互相拉扯（重传提高可靠性、延长时延）；1 μs 是抖动；100 万/km² 是同一时刻可服务的连接数；1 Gbit/s 是峰值。",
      questions: [QuestionRef(2, 5)],
      chapter: "ch02.html",
    ),
    Concept(
      id: "lpwan",
      name: "低功耗广域网（LPWAN）",
      aliases: ["NB-IoT", "LoRa", "SigFox", "Chirp-IoT"],
      cluster: Basics,
      def: "用低速率换数公里覆盖与多年电池寿命的一类广域物联网技术，含 NB-IoT、LoRa、Chirp-IoT、SigFox。",
      mechanism: "分野在频谱与建网主体：NB-IoT 占授权频谱、走运营商蜂窝网，干扰可控、有服务质量保障，但要付费并受建网节奏约束；LoRa 系占非授权频谱、自建自组网，自主但干扰与运维自担。判据是要服务质量、能忍受运营商就选 NB-IoT，要自主部署就选 LoRa 系。",
      caliber: "",
      questions: [],
      chapter: "ch02.html",
    ),
    Concept(
      id: "cloud-computing",
      name: "云计算",
      aliases: ["IaaS", "PaaS", "SaaS"],
      cluster: Basics,
      def: "分布式计算的一种：通过网络把巨大的数据处理程序分解成大量小程序，由多台服务器组成的系统处理分析并返回结果。",
      mechanism: "三种服务模式按抽象层次与用户自主权排：IaaS 给裸机与磁盘、可动态申请释放按量计费，用户自管操作系统以上全部；PaaS 给运行环境并代管弹性与容错，代价是只能用特定编程环境与模型；SaaS 只给成品软件功能，无开发自由度。七大特点讲现象，五大优势讲机制：资源池化是其余四项的前提，规模效应把网络、存储与管理成本压到中型机房的 1/5–1/7。",
      caliber: "云计算是大数据的来源和支撑，大数据是云计算的灵魂和发展方向（填空原题）。",
      questions: [QuestionRef(2, 6), QuestionRef(5, 10)],
      chapter: "ch02.html",
    ),
    Concept(
      id: "industrial-bigdata",
      name: "工业大数据",
      aliases: ["4V"],
      cluster: Basics,
      def: "围绕典型智能制造模式，在产品全生命周期各环节产生的各类数据及相关技术、应用的总称。",
      mechanism: "四类核心技术对应数据四个环节：采集（拿得到，做协议解析与时间对齐）、管理（存得下找得到，分引擎存储加统一元数据）、分析（用得上）、平台（复用得了）。来源三类：企业信息化数据、工业物联网数据（增长最快）、外部跨界数据。",
      caliber: "第五章把特征讲成基本 4V 加五项扩展，第二章只给定义与四类技术，两处指向同一批数据。",
      questions: [QuestionRef(2, 7), QuestionRef(2, 8)],
      chapter: "ch02.html",
    ),
    Concept(
      id: "multi-modal",
      name: "多模态与多源异构",
      aliases: ["多源异构", "多模态"],
      cluster: Basics,
      def: "多源异构指数据来源不同、结构或类型不同；多模态指同一批数据在不同阶段呈现不同形态。",
      mechanism: "五种形态各有存储方式：关系型（工单、BOM）走关系库，键值（设备当前状态）走键值库，时序（振动、温度）走时序库，图（批次—设备—刀具—客户的追溯链）走图库，非结构化（照片、声音）走对象存储。分引擎存完还要统一元数据与主数据，同一个对象在不同系统的名字才对得齐。",
      caliber: "",
      questions: [],
      chapter: "ch02.html",
    ),
    Concept(
      id: "discrete-process",
      name: "离散制造与流程制造",
      aliases: ["离散制造", "流程制造"],
      cluster: Basics,
      def: "按物料能否按件数清点划分：能按件数的是离散制造，只能按流量计量的是流程制造。",
      mechanism: "离散按工单与批次走工序、可停可启，度量是件数、良品率、节拍，控制靠 PLC 与 MES；流程按配方连续运行、启停成本极高，度量是吨/小时、纯度、能耗，控制靠 DCS 做回路调节、SCADA 做广域监视。",
      caliber: "",
      questions: [],
      chapter: "ch00-工厂速写.html",
    ),
    Concept(
      id: "oee",
      name: "设备综合效率（OEE）",
      aliases: ["OEE", "时间稼动率", "性能稼动率"],
      cluster: Basics,
      def: "OEE = 时间稼动率 × 性能稼动率 × 良品率。",
      mechanism: "三个乘数各管一件事：设备停没停（时间稼动率 = 实际运行时间 ÷ 计划生产时间，扣故障、换型、待料、待检）、跑得够不够快（性能稼动率 = 理论节拍 × 产量 ÷ 实际运行时间，扣空转、降速、小停机）、做出来的合不合格（良品率 = 良品数 ÷ 总产出）。客户要求「双方协商一致」，本质是要求三个数的统计口径一致。",
      caliber: "世界级水平约 85%，多数工厂 40%~60%；良品率与一次通过率（FPY）不同，FPY 把返修后合格的排除在外。",
      questions: [],
      chapter: "ch00-工厂速写.html",
    ),

    // 架构 ---------------------------------------------------------------
    Concept(
      id: "three-systems",
      name: "三大体系（网络·平台·安全）",
      aliases: ["三大核心体系"],
      cluster: Architecture,
      def: "网络是基础、平台是核心、安全是保障。",
      mechanism: "分工按输入与价值切：网络解决连得上传得动，没有它后两者无输入；平台解决算得动、存得下、建模复用，价值在这里产生；安全解决连了之后不被改不被停，是前两者的使用前提。",
      caliber: "体系架构 1.0 的三根柱子是网络、数据、安全，2.0 用平台替换数据。",
      questions: [QuestionRef(1, 3)],
      chapter: "ch03.html",
    ),
    Concept(
      id: "arch-1.0",
      name: "体系架构 1.0（2016）",
      aliases: ["体系架构 1.0"],
      cluster: Architecture,
      def: "以网络、数据、安全为三大核心：网络是工业系统互联与数据传输交换的支撑基础，数据是工业智能化的核心驱动，安全是网络与数据在工业中应用的重要保障。",
      mechanism: "应用侧拆成三大优化闭环，划分依据是优化对象的边界：面向机器设备运行优化（单台设备，靠实时感知加边缘计算）、面向生产运营优化（工厂，靠信息系统与控制系统数据集成加大数据建模）、面向企业协同与用户交互及产品服务优化（企业间）。",
      caliber: "1.0 的「数据」既是体系名又是平台职责，与网络、安全在数据功能上重叠，这是 2.0 换掉它的原因。",
      questions: [QuestionRef(3, 1)],
      chapter: "ch03.html",
    ),
    Concept(
      id: "arch-2.0",
      name: "体系架构 2.0（2019）",
      aliases: ["体系架构 2.0"],
      cluster: Architecture,
      def: "继承 1.0 的三大功能体系，以平台替换数据，由业务视图、功能架构、实施框架三大板块构成。",
      mechanism: "改动就一处，理由要说清：1.0 里网络负责传数据、安全负责护数据、数据自己又是核心，三者都绕着数据转、职责切不开；2.0 把数据的集成、管理与建模分析明确划给平台体系。换的只是名字，数据仍是核心要素、仍强调数据智能化闭环的驱动作用。",
      caliber: "",
      questions: [],
      chapter: "ch03.html",
    ),
    Concept(
      id: "three-boards",
      name: "三大板块（业务视图·功能架构·实施框架）",
      aliases: ["三大板块"],
      cluster: Architecture,
      def: "体系架构 2.0 的三个设计板块，构成商业目标与业务需求 → 系统功能定义 → 实施部署方式的设计链。",
      mechanism: "业务视图回答干什么，功能架构回答需要什么能力，实施框架回答怎么落地。三者是设计方法，与网络、平台、安全三体系不在一个层面：三体系是设计出来的内容，三板块是设计它的步骤。",
      caliber: "课件把「三大体系」与「三大板块」都叫「架构」：说体系架构 1.0 时指三体系，说 2.0 时指三板块。",
      questions: [QuestionRef(3, 2)],
      chapter: "ch03.html",
    ),
    Concept(
      id: "business-view",
      name: "业务视图",
      aliases: ["产业层·商业层·应用层·能力层"],
      cluster: Architecture,
      def: "明确企业应用工业互联网实现数字化转型的目标、方向、业务场景及相应的数字化能力，分产业层、商业层、应用层、能力层四个层次。",
      mechanism: "四层按决策主体划分：只有产业层是宏观视角（整个产业怎么转），商业层、应用层、能力层都是企业微观视角。这四层与功能架构的四层（设备、工厂、企业、产业）是两把尺子，后者按责任范围切。",
      caliber: "",
      questions: [QuestionRef(3, 3)],
      chapter: "ch03.html",
    ),
    Concept(
      id: "functional-arch",
      name: "功能架构（4 层 × 3 体系）",
      aliases: ["4 层 × 3 体系", "能力矩阵"],
      cluster: Architecture,
      def: "把三张功能视图摞起来、纵向切成设备层、工厂层、企业层、产业层四个层次，横轴为网络、平台、安全三套体系，交叉格是某层需要的某类能力。",
      mechanism: "它是乘法表：每一层都要同时实现三类能力，只是侧重不同，任何项目都能在矩阵里定位自己缺哪一格。填格的意义在区分同名不同物——设备层的「平台」是边缘网关，企业层的「平台」是 ERP 云平台，两者都在平台这一列，内容完全不同。",
      caliber: "「4 层」讲责任范围（单机→工厂→企业→产业），与设备实际放在哪无关；MES、ERP、PLM、WMS、PHM 等信息系统在企业层，不在设备层。",
      questions: [],
      chapter: "ch03.html",
    ),
    Concept(
      id: "core-principle",
      name: "核心功能原理",
      aliases: [],
      cluster: Architecture,
      def: "基于数据驱动的物理系统与数字空间的全面互联与深度协同，以及在此过程中的智能分析与决策优化。",
      mechanism: "三步：给真实工厂建一个实时同步的数字影子（互联、协同），在影子上分析（智能分析），用结论把真实工厂调回去（决策优化）。它是数字孪生与边云协同的总纲。",
      caliber: "",
      questions: [QuestionRef(3, 4)],
      chapter: "ch03.html",
    ),
    Concept(
      id: "layer-device",
      name: "设备层",
      aliases: [],
      cluster: Architecture,
      def: "功能架构的最内层，覆盖单台设备、单个工位。",
      mechanism: "代表要素是智能机器、专用设备、成套设备、仪器仪表；网络是现场总线、工业以太网、TSN、无线接入；典型系统是 PLC、传感器、伺服、刀库，数据周期毫秒到秒。",
      caliber: "",
      questions: [],
      chapter: "ch03.html",
    ),
    Concept(
      id: "layer-factory",
      name: "工厂层",
      aliases: [],
      cluster: Architecture,
      def: "功能架构中覆盖整个厂的一层，承上启下。",
      mechanism: "代表要素是生产控制网络、边缘设备接入、工业数据采集、SCADA/DCS、PLC/CNC；网络要求高可靠、高安全、高融合；典型系统是 MES、WMS、能源管理，数据周期分钟到小时。",
      caliber: "",
      questions: [],
      chapter: "ch03.html",
    ),
    Concept(
      id: "layer-enterprise",
      name: "企业层",
      aliases: [],
      cluster: Architecture,
      def: "功能架构中覆盖多厂、集团的一层。",
      mechanism: "代表要素是企业与园区网络、云平台服务、云边协同设施、公有云与私有云；典型系统是 ERP、PLM、SCM，数据周期天到月。",
      caliber: "",
      questions: [],
      chapter: "ch03.html",
    ),
    Concept(
      id: "layer-industry",
      name: "产业层",
      aliases: [],
      cluster: Architecture,
      def: "功能架构的最外层，跨企业。",
      mechanism: "代表要素是国家或集团骨干网络、专线网络、运营商网络、IPv4/IPv6；网络要求低时延、高可靠、大带宽；典型系统是工业互联网平台与标识解析的顶级、二级节点，数据周期天到月。",
      caliber: "业务视图里也有一个「产业层」，那里指站在产业整体看的宏观视角，不是责任范围。",
      questions: [],
      chapter: "ch03.html",
    ),
    Concept(
      id: "deployment-systems",
      name: "四大实施系统",
      aliases: ["网络系统·标识系统·平台系统·安全系统"],
      cluster: Architecture,
      def: "实施框架落地为网络系统、标识系统、平台系统、安全系统四个可分别立项、分别验收的工程。",
      mechanism: "三体系变四系统，多出来的是标识：到施工图阶段，标识解析被从网络体系里单拎出来，因为它是「名字对不上」这个问题的根，必须独立建设、独立验收。",
      caliber: "",
      questions: [],
      chapter: "ch03.html",
    ),
    Concept(
      id: "safety-attributes",
      name: "五大安全属性",
      aliases: ["可靠性保密性完整性可用性隐私和数据保护"],
      cluster: Architecture,
      def: "可靠性、保密性、完整性、可用性、隐私和数据保护。",
      mechanism: "五个属性定义保护到什么程度，与设备、控制、网络、应用、数据五个对象正交相乘，才是安全体系架构那张图。相比互联网经典的 CIA 三要素多出两个：可靠性（工业系统不能宕机，CIA 只保证用得到、不保证不中断）与隐私和数据保护（工艺参数是商业机密，员工与用户信息是个人数据）。",
      caliber: "这门课有四套「五」：五大属性（保护到什么程度）、五个维度（保护谁）、五类威胁（攻击从哪进）、第二章风险五类（设备、网络、数据、控制、管理）。",
      questions: [],
      chapter: "ch03.html",
    ),

    // 网络 ---------------------------------------------------------------
    Concept(
      id: "network-system",
      name: "网络体系",
      aliases: ["网络功能视图"],
      cluster: Network,
      def: "由网络互联、数据互通、标识解析三部分组成，分别解决连得上、听得懂、找得到。",
      mechanism: "顺序是连 → 懂 → 找，三者递进：先有链路，才有语义，才有身份查询；三者合起来才构成一个可寻址的网络。",
      caliber: "与物联网三层的「网络层」同名不同物：三层按采集—传输—处理切，网络层只管传输；网络体系按连—懂—找切，还管语义互通与身份寻址，后两者在物联网三层里没有位置。",
      questions: [QuestionRef(3, 5), QuestionRef(3, 6)],
      chapter: "ch03.html",
    ),
    Concept(
      id: "network-interconnect",
      name: "网络互联",
      aliases: ["连"],
      cluster: Network,
      def: "通过有线、无线方式将人、机、物、料、法、环全要素及上下游、智能产品、用户连接，支撑多要求数据转发，实现端到端数据传输。",
      mechanism: "三层递进：多方式接入（有线用现场总线、工业以太网、工业 PON、TSN；无线用 5G/4G、WiFi6、WIA、WirelessHART、ISA100.11a）→ 网络层转发（实时与非实时数据转发、网络控制、网络管理）→ 传输层传送（端口管理、端到端连接管理、安全管理）。",
      caliber: "",
      questions: [QuestionRef(3, 6)],
      chapter: "ch03.html",
    ),
    Concept(
      id: "data-interchange",
      name: "数据互通",
      aliases: ["懂"],
      cluster: Network,
      def: "实现数据和信息在各要素间、各系统间无缝传递，使异构系统在数据层面相互理解。",
      mechanism: "三层：应用层通信（OPC UA、MQTT、HTTP）→ 信息模型（OPC UA、MTConnect、YANG）→ 语义互操作（OPC UA、PLCopen、AutoML）。链路通了只证明数据到达，字段名、单位、量纲不一致时数据能到达却无法计算，所以信息模型必须单独成层。",
      caliber: "",
      questions: [QuestionRef(3, 6)],
      chapter: "ch03.html",
    ),
    Concept(
      id: "identifier",
      name: "工业互联网标识",
      aliases: ["标识编码"],
      cluster: Network,
      def: "通过数字化、编码或其他形式的唯一识别符号，为工业物品、设备、产品等实体赋予独特标识，使其在互联网环境中被唯一识别、定位和管理。",
      mechanism: "三个作用：唯一识别物理实体与数字实体、支撑网络互联互通、支撑数据共享共用。编码按段分配（国家—厂商/设备—城市—序列号），各主体只在自己那一段内编号，上级按段前缀转发即可，解析不必查全表。",
      caliber: "IP 给接口与位置编号、随网段变化；标识给对象与身份编号、终身不变。两者分离后，同一台设备换厂区、换网段仍能被同一标识引用。",
      questions: [QuestionRef(4, 1)],
      chapter: "ch04.html",
    ),
    Concept(
      id: "passive-carrier",
      name: "被动标识载体",
      aliases: ["条形码", "二维码", "RFID 标签", "NFC"],
      cluster: Network,
      def: "不具供电与通信能力、靠外部读取的载体，包括条形码、二维码、RFID、NFC。",
      mechanism: "成本可压到极低、寿命等同印刷、无需维护；但只存固化编码，读不出运行状态。它只回答「这是一个什么」，回答不了「它现在在哪、状态如何」。",
      caliber: "难点在唯一性与防复制：贴纸可撕、可仿，载体侧没有算力，只能靠读取端与后台补加密。",
      questions: [QuestionRef(4, 2)],
      chapter: "ch04.html",
    ),
    Concept(
      id: "active-carrier",
      name: "主动标识载体",
      aliases: ["UICC", "MCU", "通信模组"],
      cluster: Network,
      def: "自带供电与通信能力、可主动联网上报的载体，包括 UICC、MCU、通信模组、终端。",
      mechanism: "能主动上报实时状态与位置，支撑「这把刀装在哪台机床上、加工了多少件」这类追踪；代价是供电、成本与维护，而且联网即扩大攻击面，必须配套认证与加密。",
      caliber: "选型判据只有一条：是否需要实时状态。要追实时状态，被动载体交不了差。",
      questions: [QuestionRef(4, 2)],
      chapter: "ch04.html",
    ),
    Concept(
      id: "id-system",
      name: "标识解析体系",
      aliases: ["解析设施"],
      cluster: Network,
      def: "整套标识解析设施，由标识编码、标识载体、解析节点、标识解析四部分组成。",
      mechanism: "四部分分工：编码解决怎么编号、载体解决贴什么、解析节点解决谁来回话、标识解析解决按编码查到地址与信息。分层的原因是可扩展与数据主权——上级只存「下一跳在哪」，对象数据留在企业节点，做到编码统一、数据分散。",
      caliber: "体系是设施，标识解析是动作，两者同名不同物：看到「解析节点」说的是设施，看到「解析一次」说的是动作。",
      questions: [],
      chapter: "ch04.html",
    ),
    Concept(
      id: "id-resolution",
      name: "标识解析",
      aliases: ["找"],
      cluster: Network,
      def: "对标识编码进行解析，实现信息查询和定位，支撑跨企业、跨行业、跨地域的数据互通和精准协同。",
      mechanism: "流程是发起方提交标识 → 解析节点逐级寻址 → 找到该标识所关联对象的地址 → 返回信息对象。核心内容两部分：标识编码解决怎么编号、谁分配，标识解析解决怎么查到。",
      caliber: "",
      questions: [QuestionRef(3, 6), QuestionRef(4, 3)],
      chapter: "ch04.html",
    ),
    Concept(
      id: "parse-hierarchy",
      name: "解析节点层级",
      aliases: ["公共递归节点", "国家顶级节点", "二级节点", "企业节点"],
      cluster: Network,
      def: "国际根节点、国家顶级节点、二级节点、企业节点四层，另设公共递归节点挂在查询侧。",
      mechanism: "国际根对接 Handle 根系统 MPA，中国以 GHR 接入、其下还有 ARS 与 LHS；国家顶级节点管理全国编码与解析服务；二级节点面向行业或区域汇聚，是集成创新应用的主要抓手；企业节点存放本企业对象数据。公共递归节点代理发起方一次完成多级查询并缓存，避免热点标识每次都从根走一遍。",
      caliber: "注册层级是四层，课件把查询侧的递归节点也算进来称「五层」；递归节点不参与编码分配，只负责查。",
      questions: [QuestionRef(4, 4)],
      chapter: "ch04.html",
    ),
    Concept(
      id: "factory-intranet",
      name: "工厂内网络（两层三级）",
      aliases: ["两层三级"],
      cluster: Network,
      def: "实现工厂内部人、物、机互联的网络，结构为两层三级：两层是 IT 网络与 OT 网络，三级是工厂级、车间级、现场级。",
      mechanism: "IT 覆盖工厂级与企业级，承载 ERP、MES、办公、数据中心；OT 覆盖车间级与现场级，承载 SCADA/HMI、PLC/DCS、传感器与执行器。按业务纵向再切成生产网、办公网、安防网、企业数据中心，生产网内部再分控制类、采集类、连接类，目的是能分别设 QoS 与安全策略。",
      caliber: "全书三套「层」不是同一把尺子：物理空间（厂区→车间→工段→产线→工位）、网络归属（现场/车间/工厂级）、责任范围（设备/工厂/企业/产业）；产业层在两层三级里没有对应。",
      questions: [QuestionRef(4, 5), QuestionRef(4, 6)],
      chapter: "ch04.html",
    ),
    Concept(
      id: "it-ot",
      name: "IT 与 OT",
      aliases: ["信息技术网络", "运营技术网络"],
      cluster: Network,
      def: "IT 是信息技术网络，服务管理信息；OT 是运营技术网络，服务生产控制。",
      mechanism: "四处差别：目标上 IT 求吞吐、通用协议、频繁升级，OT 求周期确定、可用性、长生命周期；实时性上 IT 尽力而为，OT 硬实时；故障后果上 IT 是业务中断，OT 是停产、设备损坏甚至人身风险；更新窗口上 IT 随时，OT 只能检修窗口。故障后果的差别就是两者必须隔离的理由。",
      caliber: "",
      questions: [QuestionRef(4, 6)],
      chapter: "ch04.html",
    ),
    Concept(
      id: "factory-extranet",
      name: "工厂外网络（三专线一连接）",
      aliases: ["三专线一连接"],
      cluster: Network,
      def: "连接工厂、分支、上下游企业、云数据中心、智能产品与用户的网络，由上网专线、互联专线、上云专线三条专线加上网连接构成。",
      mechanism: "四类业务按「对端是谁」分：上网专线对公网，需求是访问互联网资源；互联专线对异地厂区与分支机构，要求端到端隔离与可预期时延；上云专线对工业云数据中心，要大带宽、低成本入云；上网连接对出厂产品与移动作业，要移动性与广覆盖。",
      caliber: "",
      questions: [QuestionRef(4, 5), QuestionRef(4, 7)],
      chapter: "ch04.html",
    ),
    Concept(
      id: "mpls-vpn",
      name: "MPLS VPN 专线",
      aliases: ["MPLS"],
      cluster: Network,
      def: "用多协议标记交换在共享承载网上切出逻辑隔离的虚拟专用网。",
      mechanism: "按需开通、成本低，适合灵活互联；转发仍走共享网，会受拥塞影响，时延上界不如硬管道。实践分工是 MPLS 做灵活互联、OTN 做重载骨干。",
      caliber: "",
      questions: [],
      chapter: "ch04.html",
    ),
    Concept(
      id: "otn",
      name: "光传送网（OTN）",
      aliases: ["OCH", "OMS", "OTS"],
      cluster: Network,
      def: "在光层提供硬管道的传送网，分光通道层 OCH、光复用段层 OMS、光传输段层 OTS。",
      mechanism: "给独享波长或子波长，带宽大、抖动小，适合承载生产控制这类对确定性要求高的业务；代价是开通慢、成本高、颗粒度粗。",
      caliber: "",
      questions: [],
      chapter: "ch04.html",
    ),
    Concept(
      id: "sdn-wan",
      name: "SDN 与 SD-WAN",
      aliases: ["软件定义网络", "软件定义广域网"],
      cluster: Network,
      def: "SDN 把控制平面从设备抽到集中控制器、由控制器统一编排转发；SD-WAN 是这套架构在企业广域网上的落地。",
      mechanism: "广域网多链路（DSL、Fiber、LTE）逐台配置、静态选路，无法按应用调度；SD-WAN 让控制器统一编排多链路、按业务选路、叠加加密，用低价链路承载高价值业务。",
      caliber: "",
      questions: [],
      chapter: "ch04.html",
    ),
    Concept(
      id: "protocol-interop",
      name: "异构协议互通",
      aliases: ["协议网关"],
      cluster: Network,
      def: "让 Profinet、EtherNet/IP、Modbus、无线协议等异构报文互通的三类手段。",
      mechanism: "①中间件和网关设备；②协议适配器和转换器软件；③协议数据格式转换。三者原理相同：先把报文解析成统一数据模型再上行。这是多协议共存的最低成本解，代价是网关本身成为单点与延迟来源。",
      caliber: "",
      questions: [QuestionRef(4, 9)],
      chapter: "ch04.html",
    ),
    Concept(
      id: "tsn",
      name: "时间敏感网络（TSN）",
      aliases: ["TSN", "802.1AS", "802.1Qbv", "802.1CB"],
      cluster: Network,
      def: "IEEE 802.1 制定的一组以太网增强标准，在标准以太网上实现确定性通信，确保关键数据在严格时间限制内以低延迟、低抖动、高可靠传输。",
      mechanism: "核心原理是全局时钟加传输调度器：802.1AS 给全网同一时间基准，802.1Qbv 门控按时隙只放行指定流，关键流不与背景流量争抢队列，最坏时延与抖动因此可计算；再叠加 802.1CB 的冗余路径与帧复制消除把丢包率压到极低。传统工业以太网靠优先级排队、拥塞时不可界，TSN 靠时间片预约、拥塞也不影响。",
      caliber: "它针对传统工业以太网的四个问题：实时性差、数据抖动、传输碰撞、资源竞争。",
      questions: [QuestionRef(4, 10)],
      chapter: "ch04.html",
    ),
    Concept(
      id: "edge-computing",
      name: "边缘计算",
      aliases: ["MEC"],
      cluster: Network,
      def: "在靠近物或数据源头的网络边缘侧，融合网络、计算、存储、应用（第五章加智能）核心能力的分布式开放平台，就近提供边缘智能服务。",
      mechanism: "因集中式云的四个约束而生：实时性（回传与排队时延）、带宽（原始数据量）、能耗、隐私与数据保护。功能视图给自动化控制、分析、优化三类功能，由边缘管理器做业务编排与资源调用；能力视图给计算、网络、存储三类能力。五类资源合起来才叫边缘智能：本地能跑完接入—缓存—推理—执行一整圈，云断了自己还能跑。",
      caliber: "「边缘层」是平台功能架构里的一层（负责接入、转换、预处理）；「边缘计算」是部署形态。层说的位置，计算说的能力。",
      questions: [QuestionRef(4, 11), QuestionRef(5, 11)],
      chapter: "ch04.html",
    ),

    // 平台 ---------------------------------------------------------------
    Concept(
      id: "industrial-platform",
      name: "工业互联网平台",
      aliases: ["工业云平台"],
      cluster: Platform,
      def: "面向制造业数字化、网络化、智能化需求，构建基于海量数据采集、汇聚、分析的服务体系，支撑制造资源泛在连接、弹性供给、高效配置的工业云平台。",
      mechanism: "本质是数据＋模型＝服务：数据是原料（量大、异构、无直接语义），模型是增值环节（把主轴电流 12.3 A 变成刀具剩余寿命 18 小时），服务是价值出口（可交付、可计量、可签合同）。缺数据则模型只靠假设，缺模型则数据只是存储成本，不落成服务则无法计价。",
      caliber: "",
      questions: [QuestionRef(5, 1)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "platform-system",
      name: "平台体系（边缘层·PaaS·应用层）",
      aliases: ["平台功能视图"],
      cluster: Platform,
      def: "按功能层级分三层：边缘层、PaaS 层、应用层。",
      mechanism: "划分依据是离设备的距离：边缘层处理来不及上传、也不该上传的数据；PaaS 层做复用（一次建模、多次调用）；应用层面向具体业务交付。白皮书口径另单列 IaaS，成为四层。",
      caliber: "白皮书四层（边缘层、IaaS 层、平台层、应用层）与第三章功能视图三层（边缘层、PaaS 层、应用层）是同一套东西的两种切法；题干出现 IaaS 就按四层答。",
      questions: [QuestionRef(3, 7), QuestionRef(5, 2)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "edge-layer",
      name: "边缘层",
      aliases: [],
      cluster: Platform,
      def: "平台功能架构的最底层，通过大范围、深层次数据采集及异构数据的协议转换与边缘处理，构建平台的数据基础。",
      mechanism: "现场协议异构、数据量大，先在离设备最近处做转换与预处理，把上行数据量和时延压下来；它不承担建模复用，那是平台层的事。",
      caliber: "",
      questions: [],
      chapter: "ch05.html",
    ),
    Concept(
      id: "platform-layer",
      name: "平台层（工业 PaaS）",
      aliases: ["PaaS 层", "云操作系统"],
      cluster: Platform,
      def: "基于通用 PaaS 叠加大数据处理、工业数据分析、工业微服务，构建可扩展的开放式云操作系统。",
      mechanism: "工业知识在这里固化为可复用组件：微服务把一项能力拆成可独立部署、可组合复用的小服务，一次建模多处调用。它是核心的原因：边缘层是数据入口、应用层是价值出口，只有这一层沉淀模型与微服务；没有它，每个应用都要重写一遍模型，成本无法摊薄。",
      caliber: "与功能架构四层里「平台层」的用法不同：那里指 PaaS 那一段，与边缘层、应用层并列；这里指整个平台体系的核心层。",
      questions: [],
      chapter: "ch05.html",
    ),
    Concept(
      id: "platform-tech-arch",
      name: "平台技术架构",
      aliases: ["基础技术", "使能技术", "信息安全技术"],
      cluster: Platform,
      def: "平台的技术架构分三部分：基础技术、使能技术、信息安全技术。",
      mechanism: "判据在问法：问「平台由哪几层组成」是功能架构，问「平台由哪几部分技术组成」是技术架构。基础技术撑运行（云基础设施、通用 PaaS、数据管理组件），使能技术给工业能力（感知、通信、CPS 与控制系统、大数据、云计算与边缘计算、数字孪生），信息安全技术保底线。",
      caliber: "",
      questions: [QuestionRef(5, 3), QuestionRef(5, 5)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "sensing-tech",
      name: "感知技术",
      aliases: [],
      cluster: Platform,
      def: "负责采集工业现场数据的三类技术：传感器技术、RFID 技术、工业机器视觉技术。",
      mechanism: "三者分工是测物理量、认身份、看外观：传感器把非电量转成电学量，用于温度、振动、压力、力矩的状态监测与工艺采集；RFID 非接触读写标签，用在在制品追踪、刀具管理与产线防错；机器视觉用图像抽特征，做识别、检测、测量、定位。",
      caliber: "",
      questions: [QuestionRef(5, 4)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "rfid",
      name: "射频识别（RFID）",
      aliases: ["RFID"],
      cluster: Platform,
      def: "通过无线电信号识别特定目标并读写相关数据、无需机械或光学接触的无线通信技术。",
      mechanism: "系统由阅读器、电子标签、应用管理系统组成，电子标签由天线与 IC 芯片（射频模块、控制模块、存储器）构成。工作频率决定最远阅读距离：频率定波长，波长定近场还是远场，耦合方式随之改变（近场磁场耦合、远场对反射信号调制），通信距离由标签反射能量与阅读器灵敏度决定。",
      caliber: "",
      questions: [],
      chapter: "ch05.html",
    ),
    Concept(
      id: "machine-vision",
      name: "工业机器视觉",
      aliases: [],
      cluster: Platform,
      def: "通过加装视觉装置的机器代替人眼完成引导、检测、测量、识别。",
      mechanism: "系统分明暗两部分：前置部分含照明与成像、在现场，后置部分在计算机内做处理。图像摄取装置把目标转成图像信号，按像素分布与亮度、颜色转成数字信号，运算抽取特征后控制现场设备动作。",
      caliber: "",
      questions: [],
      chapter: "ch05.html",
    ),
    Concept(
      id: "smart-sensor",
      name: "智能传感器",
      aliases: ["微型传感器", "多功能智能传感器"],
      cluster: Platform,
      def: "集成传感器、微处理器和通信功能，在内部完成原始数据加工、可通过标准接口交换数据、能用软件改变工作模式的传感系统。",
      mechanism: "由传感模块、智能处理模块、通信模块组成。把处理下沉到传感器内部、只上传结果，减少总线占用与上位机负荷；软件可改工作模式，同一硬件适配多种测量需求。多传感器信息融合分原始数据层、特征层、决策层，传得越原始信息越多、带宽与实时性代价越大。",
      caliber: "新型传感器三个方向：微型（MEMS 做到毫米级）、智能（带微处理器就地滤波标定提特征）、多功能（多物理量同时采集并融合），共同趋势是微型化、数字化、智能化、网络化。",
      questions: [],
      chapter: "ch05.html",
    ),
    Concept(
      id: "cps",
      name: "信息物理系统（CPS）",
      aliases: ["CPS"],
      cluster: Platform,
      def: "构建赛博空间与物理空间之间基于数据自动流动的状态感知、实时分析、科学决策、精准执行闭环赋能体系。",
      mechanism: "cyber 是计算与网络组成的信息世界（离散计算进程、逻辑通信过程、反馈控制过程），physical 是物理世界中按客观规律在连续时间上运行的进程与对象。三个层次按数据自动流动的范围从小到大：单元级、系统级、SoS 级，判据是互联手段——没有网络的是单元级，靠工业网络的是系统级，靠大数据平台跨系统集成的是 SoS 级。",
      caliber: "CPS 三层与功能架构四层可粗略对应：单元级≈设备层、系统级≈工厂层、SoS 级≈企业层与产业层。",
      questions: [QuestionRef(5, 6)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "plc",
      name: "可编程逻辑控制器（PLC）",
      aliases: ["PLC"],
      cluster: Platform,
      def: "以计算机技术为基础、专为工业环境应用设计的数字运算操作电子装置，用可编程存储器存程序，执行逻辑、顺序、定时、计数与算术运算，经数字或模拟 I/O 控制机械或生产过程。",
      mechanism: "工作方式是循环扫描，三阶段输入采样 → 用户程序执行 → 输出刷新，执行一次即扫描周期。集中采样、集中执行、集中输出让输出与外部瞬时扰动解耦，抗干扰且时序确定；代价是输入变化要等一个扫描周期才反映到输出，实时性受扫描周期限制，中大型 PLC 因此增加中断方式处理紧急事件。",
      caliber: "PLC 属于单元级 CPS；DCS 与 SCADA 属于系统级 CPS。",
      questions: [QuestionRef(5, 7)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "dcs",
      name: "分布式控制系统（DCS）",
      aliases: ["DCS", "4C"],
      cluster: Platform,
      def: "用于工业生产过程、实现分散控制与集中管理的分布式自动化控制系统，集计算机、通信、CRT、控制技术（4C）于一体。",
      mechanism: "组成四件：现场控制站、操作员站、工程师站、系统网络；分三级：控制级、监控级、管理级。控制回路分散到各现场控制站，单点或局部故障不导致全局失效；上位机集中监视管理，上下位机经控制网络互联，兼顾分散与集中。",
      caliber: "",
      questions: [QuestionRef(5, 7)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "scada",
      name: "数据采集与监视控制系统（SCADA）",
      aliases: ["SCADA"],
      cluster: Platform,
      def: "由计算机设备、工业过程控制组件和网络组成的控制系统，含数据采集与监视控制两个层次功能，数据采集是基础。",
      mechanism: "一个主站加多个子站，经广域网通信，用于测控点十分分散、分布范围广泛的对象；控制思想是管理集中、控制分散，即使上下位机通信中断，现场测控装置仍能正常工作。",
      caliber: "三者判据只有一条——控制对象是否地理集中：单机装置用 PLC，同一厂区系统用 DCS，跨厂站分散测点用 SCADA。",
      questions: [QuestionRef(5, 7)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "bigdata-features",
      name: "工业大数据的特征（4V 与扩展）",
      aliases: ["4V", "重机理"],
      cluster: Platform,
      def: "基本 4V：大体量、类型杂、价值密度低、变化快。",
      mechanism: "四个特征各自约束一种处理方式：大体量（单企业可达 PB 甚至 EB）逼出分布式存储；类型杂逼出按模态分引擎存储加统一元数据；价值密度低来自 7×24 采集下正常样本天然占绝大多数，所以要先建正常模式、异常才有参照；变化快要求流式处理与随工况更新的模型。五项扩展是多模态、跨尺度、高通量、重机理、强关联，其中重机理是工业数据与消费数据最大的不同：纯数据驱动在异常样本稀少时定不了根因。",
      caliber: "",
      questions: [QuestionRef(5, 8)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "bigdata-arch",
      name: "工业大数据功能体系",
      aliases: ["采集交换·集成处理·建模分析·决策控制"],
      cluster: Platform,
      def: "四层单向增值链：数据采集与交换、数据集成与处理、数据建模与分析、决策与控制应用。",
      mechanism: "前层输出即后层输入，跳层则模型缺少干净输入。技术架构用两域描述同一套系统：平台/工具域（离线，存储、计算引擎、算法库、开发工具）回答模型怎么做出来，应用/服务域（在线，查询、监控、决策）回答模型怎么在业务里跑起来。",
      caliber: "第二章的「技术架构四层」写作采集交换层、集成处理层、建模分析层、决策控制层，与这里的四层是同一链。",
      questions: [QuestionRef(2, 9), QuestionRef(2, 10), QuestionRef(5, 9)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "knowledge-graph",
      name: "工业知识图谱",
      aliases: ["知识图谱"],
      cluster: Platform,
      def: "把工厂中的人、设备、材料、工艺、环境、测量及故障、经验、因果构建成机器可理解、可推理的结构化知识网络。",
      mechanism: "专家经验大量沉积在维修工单、工艺文件、故障记录等非结构化文本里，只有固化为可推理的知识网络才能复用。它与多源数据融合的分工：图谱沉淀「为什么」，融合回答「是不是」——设备数据说异常、ERP 说订单变更，单来源定不了根因，必须交叉验证。",
      caliber: "",
      questions: [],
      chapter: "ch05.html",
    ),
    Concept(
      id: "cloud-deploy",
      name: "云部署模型",
      aliases: ["公有云", "私有云", "混合云", "社区云"],
      cluster: Platform,
      def: "四种部署模型：公有云、社区云、私有云、混合云。",
      mechanism: "按所有权与访问方式划分；另有按受众的消费者云、企业云与按用途的行业云，本质是四类的分割或组合。私有云资源独占、数据所有权与隐私可控，代价是失去云计算的弹性——资源固定，无法按需伸缩。",
      caliber: "",
      questions: [QuestionRef(5, 10)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "edge-cloud-collab",
      name: "边云协同",
      aliases: ["模型下发数据上送"],
      cluster: Platform,
      def: "边缘计算与云计算相结合、把云端服务扩展到边缘端的分工机制。",
      mechanism: "分工按时效切：边缘向云反馈信息，负责实时、短周期分析与本地执行，毫秒级响应、断网可自治；云向边缘发布指令，负责非实时、长周期的大数据分析与业务决策。云端训练模型、边缘推理与实时控制，形成模型下发、数据上送的闭环。",
      caliber: "边缘计算回答「在何处算」，边云协同回答「边与云如何分工」，两者是同一块地方的两个问题。",
      questions: [QuestionRef(5, 11)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "digital-twin",
      name: "数字孪生",
      aliases: ["Digital Twin"],
      cluster: Platform,
      def: "物理对象的数字模型，可通过接收物理对象的数据实时演化，与物理对象在全生命周期保持一致，并把仿真结果反馈给物理对象。",
      mechanism: "三特征：实时同步、双向交互、全生命周期映射；系统由数字模型、物理实体、数据三部分组成。与仿真的判据是有无实时数据驱动与双向交互：仿真是一次性的离线计算，孪生是用实时数据持续校正并回馈物理对象。",
      caliber: "1991 年 Gelernter 提出基本想法，2010 年 11 月 NASA 报告首次使用 Digital Twin 一词。",
      questions: [QuestionRef(5, 12)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "three-platforms",
      name: "三大平台（Predix·MindSphere·INDICS）",
      aliases: ["Predix", "MindSphere", "INDICS"],
      cluster: Platform,
      def: "Predix（GE，2013）三层、MindSphere（西门子，2016）三层、INDICS（中国航天科工，2015 启动、2017.6 发布）四层。",
      mechanism: "Predix 是边缘层、云平台层、应用服务层，边缘靠 Predix Machine、PaaS 用 CloudFoundry、主打资产性能管理；MindSphere 是应用层、开放式 PaaS 层、连接层，连接靠 MindConnect、托管在 AWS/Azure/阿里云；INDICS 是边缘层、IaaS、PaaS、应用层，以云制造为理论支撑、是三家中唯一单列 IaaS 的。共通性是本质都为基于云的开放式物联网操作系统，边缘层是前提、IaaS 是基础、工业 PaaS 是核心；层数差异反映各家对 IaaS 是否自建、边缘是否单列的选择不同。",
      caliber: "",
      questions: [QuestionRef(5, 13), QuestionRef(5, 14)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "platform-apps",
      name: "平台三个应用方向",
      aliases: ["智能制造", "网络协同制造", "云制造"],
      cluster: Platform,
      def: "智能制造、网络协同制造、云制造，作用范围依次是企业内部、跨企业、制造资源池化。",
      mechanism: "智能制造面向企业内部全要素全过程，平台形态多为企业内部云平台；网络协同制造跨专业、跨企业、跨地域做协同设计、仿真、试验、生产与保障，形态多为行业云或混合云；云制造把制造资源与能力虚拟化、服务化构成服务云池。选行业云或混合云的理由是跨企业共享需要跨组织数据通路，而核心数据不宜全部外置公有云。",
      caliber: "",
      questions: [QuestionRef(5, 15)],
      chapter: "ch05.html",
    ),
    Concept(
      id: "cloud-manufacturing",
      name: "云制造",
      aliases: ["服务云池"],
      cluster: Platform,
      def: "基于泛在网络、面向服务的智慧化制造新模式，把各类制造资源和制造能力虚拟化、服务化构成服务云池，用户按需获取。",
      mechanism: "用户不再买设备，而是按需取用池里的制造能力；由泛在网络提供可达性、由服务化提供计量与计费。INDICS 以它为理论支撑。",
      caliber: "",
      questions: [QuestionRef(5, 15)],
      chapter: "ch05.html",
    ),

    // 安全 ---------------------------------------------------------------
    Concept(
      id: "stuxnet",
      name: "震网病毒（Stuxnet）",
      aliases: ["超级工厂病毒"],
      cluster: Security,
      def: "首个专门针对工业控制系统的破坏性蠕虫，也是全球第一个主动攻击真实世界基础设施的蠕虫。",
      mechanism: "攻击伊朗纳坦兹核工厂的西门子工控系统，路径六步：感染、扫描、更新、破坏、控制、欺骗与摧毁；第六步伪造监控读数，操作员看到的仍是正常曲线。它穿过了气隙——物理隔离只切断网络路径，不消除介质入口（维护笔记本、移动存储、厂商远程升级）。",
      caliber: "",
      questions: [QuestionRef(6, 1)],
      chapter: "ch06.html",
    ),
    Concept(
      id: "threat-five",
      name: "五类安全威胁",
      aliases: ["五类风险"],
      cluster: Security,
      def: "设备安全、控制安全、网络安全、应用安全、数据安全。",
      mechanism: "五者按控制流与数据流串联成链：入口通常在网络层或应用层（IT 侧），后果落在控制层与设备层（OT 侧）；任一层被突破后，攻击者可用该层权限向相邻层横向移动，所以防护必须逐层设卡，任一层失守都会使其余层暴露。",
      caliber: "第二章 P89 的另一版是设备、网络、数据、控制、管理，用「管理」占了「应用」的位置；本课按设备、控制、网络、应用、数据记。",
      questions: [QuestionRef(2, 11), QuestionRef(6, 2)],
      chapter: "ch06.html",
    ),
    Concept(
      id: "security-dimensions",
      name: "五个安全维度",
      aliases: ["五个保护对象"],
      cluster: Security,
      def: "按保护对象切分的五个方向：设备、控制、网络、应用、数据。",
      mechanism: "每一维单独设防：设备防固件被改与漏洞未补、硬件被替换，控制防控制指令被伪造与逻辑被篡改，网络防边界被穿透、流量被劫持、可用性被打掉，应用防平台与 App 的漏洞与越权，数据防传输存储被窃取与敏感字段未脱敏。这五个对象与五大属性正交相乘，就是安全体系架构。",
      caliber: "与「五类威胁」是同一组对象换视角：这里说保护谁，那里说攻击从哪进。",
      questions: [QuestionRef(3, 8)],
      chapter: "ch06.html",
    ),
    Concept(
      id: "dimension-shift",
      name: "五维之变",
      aliases: ["OT 层不再可信", "横向移动"],
      cluster: Security,
      def: "五个保护对象各自变了什么、因此带来什么挑战。",
      mechanism: "设备由机械结构变为 EOS＋微处理器＋应用软件，攻击面从物理操作转向代码执行，漏洞影响从特定型号扩散到海量通用设备；控制由分层封闭局部变为扁平开放全局、IT 与 OT 融合，OT 层不再可信（协议与软件普遍缺认证与加密），信息安全与功能安全交织；网络由专有协议变为以太网/IP，攻击代码可复用、门槛大降，且工业交换机性能低、短时拥塞即等价控制失效；应用变成多用户多设备多平台多工序、跨组织跨区域，单一安全域策略覆盖不住；数据由少量单向变为大量双向，泄露点随流转节点增长。",
      caliber: "",
      questions: [QuestionRef(6, 4)],
      chapter: "ch06.html",
    ),
    Concept(
      id: "security-framework",
      name: "安全体系框架",
      aliases: ["五层加新兴技术"],
      cluster: Security,
      def: "以设备、控制、网络、应用、数据五个层次组织防护技术，另设人工智能、区块链、可信计算、零信任等新兴技术支撑层。",
      mechanism: "五层即五个保护对象，每层落到具体技术：设备侧固件攻击面减少、漏洞修复与补丁管理、运维管控、硬件安全增强；控制侧身份认证、白名单、访问控制、传输加密、脆弱性测试、软件防篡改；网络侧隔离、边界管控、接入管理、传输保护、入侵检测、DDoS 防御；应用侧分平台安全与应用程序安全；数据侧按传输、处理、存储三阶段展开。",
      caliber: "框架里的「层」指防护对象的层次，与功能架构里设备层、工厂层那套「层」无关。",
      questions: [QuestionRef(2, 12), QuestionRef(3, 9), QuestionRef(6, 3)],
      chapter: "ch06.html",
    ),
    Concept(
      id: "device-security",
      name: "设备安全",
      aliases: ["FASR", "固件攻击面减少", "补丁管理"],
      cluster: Security,
      def: "对象是工业机器人、智能仪表、传感器等现场智能设备，防护五项：固件攻击面减少、漏洞修复、补丁管理、运维管控、硬件安全增强。",
      mechanism: "固件是攻击面的根：它存在硬件里、直接控制底层操作、是硬件与高级软件之间的桥梁，植入恶意代码后上层察觉不到、重装系统也清不掉，所以防护点要前移到内核与协议栈（FASR）。补丁不能打上就行——工控设备不允许随意停机，必须检测、下载、测试、批准、安装五环节，测试与批准是可用性与安全性之间的强制折中。硬件信任根解决的是软件层校验自身可被篡改。",
      caliber: "",
      questions: [QuestionRef(6, 5)],
      chapter: "ch06.html",
    ),
    Concept(
      id: "control-security",
      name: "控制安全",
      aliases: ["白名单", "脆弱性测试", "模糊测试"],
      cluster: Security,
      def: "对象是控制软件与控制协议，防护含身份认证、白名单、访问控制、传输加密、脆弱性测试、软件防篡改、恶意软件防护、安全监测与审计。",
      mechanism: "白名单成立的前提是工控指令集固定且可完整枚举，只放行已知合法能挡住未知攻击与变种，代价是设备或工况变更时须同步维护策略；认证回答你是谁，访问控制回答你能做什么；传输加密三条途径（协议栈加安全层、应用数据单元加安全字段、改进会话过程）都要付时延与兼容性代价；安全监测利用工业软件操作的周期性与时间序列做无监督异常检测，因为攻击样本稀缺、没有标注数据。脆弱性测试以模糊测试为主、占 80%，分黑盒、白盒、灰盒。",
      caliber: "",
      questions: [QuestionRef(6, 5)],
      chapter: "ch06.html",
    ),
    Concept(
      id: "network-security",
      name: "网络安全",
      aliases: ["网络隔离", "边界管控", "入侵检测", "DDoS"],
      cluster: Security,
      def: "对象是工厂内部网络、外部网络及两者边界，防护含网络隔离、边界管控、接入管理、通信与传输保护、入侵检测、DDoS 防御。",
      mechanism: "网络隔离分物理、协议、应用三类，隔离强度与成本依次递减、可用性依次递增；边界管控把无限的内网流量收敛到有限检查点，入侵识别才有可实施的位置；接入管理在连接建立前验证身份，标识解析节点被伪造可劫持寻址；入侵检测两条路线——规则库准确率高但对未知攻击无效，异常检测能发现未知但误报高，深度学习是为了压低误报；DDoS 靠负载均衡、CDN、分布式集群防御把流量分散到多个入口。",
      caliber: "工业以太网交换机以实时性与成本为设计目标，缓存与控制面处理弱，海量请求即可耗尽会话表与带宽。",
      questions: [QuestionRef(6, 5)],
      chapter: "ch06.html",
    ),
    Concept(
      id: "app-security",
      name: "应用安全",
      aliases: ["平台安全", "工业应用程序安全", "代码审计"],
      cluster: Security,
      def: "分两大类：平台安全与工业应用程序安全。",
      mechanism: "平台安全含安全审计、认证授权、安全隔离、安全监测、补丁升级、DDoS 防御；工业应用程序安全含代码审计、补丁升级、脆弱性检测、审核测试、行为监测与异常阻止。四个易混点的判据是看什么、有没有源码：代码审计白盒需源码，脆弱性检测黑盒针对已发布程序，行为监测看运行态，审核测试是上线前的流程性控制。",
      caliber: "",
      questions: [QuestionRef(6, 5), QuestionRef(6, 6)],
      chapter: "ch06.html",
    ),
    Concept(
      id: "data-security",
      name: "数据安全",
      aliases: ["脱敏", "同态加密"],
      cluster: Security,
      def: "按传输、处理、存储三阶段展开：传输加密，处理做敏感性识别、使用授权、脱敏，存储做访问控制与存储加密。",
      mechanism: "脱敏与加密的判据是是否保留可还原性：脱敏在处理阶段对敏感字段变形，数据可用但不可还原到个体；加密在传输与存储阶段用密钥保护，授权者仍可还原。智能识别保护、智能安全溯源、智能风险预警、智能精准管控四项能力补的是「从人工定规则转向用行为数据定规则」。",
      caliber: "",
      questions: [QuestionRef(6, 5)],
      chapter: "ch06.html",
    ),
    Concept(
      id: "trusted-computing",
      name: "可信计算",
      aliases: ["硬件信任根"],
      cluster: Security,
      def: "通过硬件和软件协同，确保计算设备、数据和应用程序按预期安全运行的技术体系。",
      mechanism: "从硬件信任根逐级向上度量启动链，证明当前运行的东西没被改；软件层的完整性校验自身可被篡改，所以起点必须落在不可改的硬件。它度量平台完整性，零信任逐次验证访问请求，两者解决的不是同一个问题。",
      caliber: "",
      questions: [],
      chapter: "ch06.html",
    ),
    Concept(
      id: "zero-trust",
      name: "零信任",
      aliases: ["零信任架构"],
      cluster: Security,
      def: "不默认任何位置（含内网）可信，每次访问都重新验证身份与上下文。",
      mechanism: "把权限判定从位置改为身份加上下文，解决的是「内网即可信」这个假设在 IT/OT 融合后不成立；代价是每次访问都要一次判定，对时延与可用性提出要求。",
      caliber: "",
      questions: [],
      chapter: "ch06.html",
    ),
    Concept(
      id: "blockchain",
      name: "区块链",
      aliases: ["分布式账本"],
      cluster: Security,
      def: "由区块组成的链式数据结构，是去中心化的、不可篡改的分布式账本技术。",
      mechanism: "四个特点各有机制：透明性（账本对参与方公开、任何人可复核）、不可篡改（每块含前块哈希，改一处则后续全部失效，需掌握多数节点算力才能重写）、去中心化（无中心账本，消除单点信任与单点篡改）、可追溯（链式结构保留全部历史）。技术基础四件：数字签名管身份与防抵赖、时间戳定序、分布式共识与多方存储防单方改写、智能合约把规则上链自动执行。代价是写入慢、存储冗余、隐私需额外设计，所以适合多主体、低频、需存证的场合。",
      caliber: "与数据库审计的分界是谁能单方面改写记录：链要改多数副本，日志由管理员掌控、可信性来自制度与权限。",
      questions: [QuestionRef(6, 7)],
      chapter: "ch06.html",
    ),
    Concept(
      id: "industrial-blockchain",
      name: "工业区块链",
      aliases: ["联盟数字身份", "智能合约"],
      cluster: Security,
      def: "用区块链解决工业互联网四类难题：信任构建难、数据确权流转难、数据安全共享难、事件审计追溯难。",
      mechanism: "四对四：多平台多设备缺统一可信身份用联盟数字身份（按场景签发多个联盟身份 ID 与凭证，支持自生成、自存储、自销毁）；权属与责任不清用资产标签上链、链上链下绑定、隔离通道加流转共识的访问控制；原始数据不愿共享且计算过程不透明用多方密文同态计算加留痕与激励，做到数据可用不可见；跨组织缺统一追溯用事件可信共享渠道、链上事件映射逻辑链加智能合约，把事件行为簇按时间打包成审计报告。",
      caliber: "",
      questions: [QuestionRef(6, 8)],
      chapter: "ch06.html",
    ),
  ]
}

// 超边 -------------------------------------------------------------------
//
// 二元边用 roles 表达；矩阵与选型用 cells 落成表格。result 指向被组装出来的
// 那个概念（例如三件套组装成网络体系），没有结果就留 None。

fn hyperedges() -> List(Hyperedge) {
  [
    Hyperedge(
      id: "he-network-view",
      kind: Flow,
      label: "网络功能视图：连 → 懂 → 找",
      roles: [
        Role("阶段", [
          "network-interconnect",
          "data-interchange",
          "id-resolution",
        ]),
      ],
      result: None,
      cells: [],
      note: "顺序不能调换：先有链路，才有语义，才有身份查询。",
    ),
    Hyperedge(
      id: "he-network-system",
      kind: Mapping,
      label: "网络体系 = 网络互联 + 数据互通 + 标识解析",
      roles: [
        Role("组成", [
          "network-interconnect",
          "data-interchange",
          "id-resolution",
        ]),
      ],
      result: Some("network-system"),
      cells: [
        Cell("网络互联", "解决", "连得上：多方式接入 → 网络层转发 → 传输层传送"),
        Cell("数据互通", "解决", "听得懂：应用层通信 → 信息模型 → 语义互操作"),
        Cell("标识解析", "解决", "找得到：标识注册分配编码，解析节点按前缀查询"),
      ],
      note: "超边的「结果」指向被组装出来的那个概念。",
    ),
    Hyperedge(
      id: "he-three-systems",
      kind: Mapping,
      label: "三大体系 = 网络 + 平台 + 安全",
      roles: [
        Role("组成", [
          "network-system",
          "platform-system",
          "security-framework",
        ]),
      ],
      result: Some("three-systems"),
      cells: [
        Cell("网络体系", "定位", "基础：连得上传得动，没有它后两者无输入"),
        Cell("平台体系", "定位", "核心：算得动、存得下、建模复用，价值在这里产生"),
        Cell("安全体系", "定位", "保障：连了之后不被改、不被停"),
      ],
      note: "三者是能力构成，与业务视图—功能架构—实施框架那套设计方法不在一个层面。",
    ),
    Hyperedge(
      id: "he-id-system",
      kind: Mapping,
      label: "标识解析体系 = 编码 + 载体 + 节点 + 解析",
      roles: [
        Role("标识编码", ["identifier"]),
        Role("标识载体", ["passive-carrier", "active-carrier"]),
        Role("解析节点", ["parse-hierarchy"]),
        Role("标识解析", ["id-resolution"]),
      ],
      result: Some("id-system"),
      cells: [],
      note: "编码统一、数据分散：上级只存下一跳在哪，对象数据留在企业节点。",
    ),
    Hyperedge(
      id: "he-functional-grid",
      kind: Matrix,
      label: "功能架构：4 层 × 3 体系",
      roles: [
        Role("层", [
          "layer-device",
          "layer-factory",
          "layer-enterprise",
          "layer-industry",
        ]),
        Role("体系", ["network-system", "platform-system", "security-framework"]),
      ],
      result: None,
      cells: [
        Cell("设备层", "网络", "现场总线、工业以太网、TSN、无线模组"),
        Cell("设备层", "平台", "边缘网关、设备侧嵌入式软件、智能传感器"),
        Cell("设备层", "安全", "固件安全、硬件信任根、安全芯片"),
        Cell("工厂层", "网络", "生产控制网、边缘接入、工业以太网"),
        Cell("工厂层", "平台", "MES／SCADA、边缘计算平台"),
        Cell("工厂层", "安全", "工控边界（工业防火墙）、入侵检测、网络隔离"),
        Cell("企业层", "网络", "园区网、云专线、SD-WAN"),
        Cell("企业层", "平台", "企业云平台、ERP／PLM、数据中台"),
        Cell("企业层", "安全", "企业身份与权限、审计、边界防护"),
        Cell("产业层", "网络", "国家或集团骨干网、运营商网络、专线"),
        Cell("产业层", "平台", "跨企业平台、标识解析顶级与二级节点、行业云"),
        Cell("产业层", "安全", "行业监管、威胁情报共享、跨企业身份互认"),
      ],
      note: "每格是「某层需要的某类能力」。同名不同物：设备层的平台是边缘网关，企业层的平台是 ERP 云平台。",
    ),
    Hyperedge(
      id: "he-platform-stack",
      kind: Matrix,
      label: "平台功能架构：四层各管一段",
      roles: [
        Role("层", ["edge-layer", "platform-layer"]),
        Role("体系", ["platform-system"]),
      ],
      result: None,
      cells: [
        Cell("边缘层", "作用", "数据基础：采集、协议转换与边缘处理"),
        Cell("边缘层", "为什么在这一层", "现场协议异构、数据量大，先压上行数据量与时延"),
        Cell("IaaS 层", "作用", "基础支撑与保障：虚拟化算力与存储、安全管理体系"),
        Cell("IaaS 层", "为什么在这一层", "承接海量数据，是平台的算力底座"),
        Cell("平台层", "作用", "核心：可扩展的开放式云操作系统"),
        Cell("平台层", "为什么在这一层", "模型与微服务在此沉淀，一次建模多处调用"),
        Cell("应用层", "作用", "最终价值：工业 SaaS 与工业 App"),
        Cell("应用层", "为什么在这一层", "直接面向业务，是价值出口"),
      ],
      note: "白皮书口径四层；第三章功能视图把 IaaS 并入 PaaS 表述，成三层。",
    ),
    Hyperedge(
      id: "he-security-grid",
      kind: Matrix,
      label: "安全体系：5 对象 × 5 属性",
      roles: [
        Role("对象", [
          "device-security",
          "control-security",
          "network-security",
          "app-security",
          "data-security",
        ]),
        Role("属性", ["safety-attributes"]),
      ],
      result: None,
      cells: [
        Cell("设备", "这一列主要防什么", "固件被改、漏洞未补、硬件被替换"),
        Cell("设备", "落到什么技术", "固件攻击面减少、补丁管理、硬件信任根"),
        Cell("控制", "这一列主要防什么", "控制指令被伪造、控制逻辑被篡改"),
        Cell("控制", "落到什么技术", "身份认证、白名单、软件防篡改"),
        Cell("网络", "这一列主要防什么", "边界被穿透、流量被劫持、可用性被打掉"),
        Cell("网络", "落到什么技术", "网络隔离、边界管控、入侵检测、DDoS 防御"),
        Cell("应用", "这一列主要防什么", "平台与 App 的漏洞、越权访问"),
        Cell("应用", "落到什么技术", "代码审计、脆弱性检测、行为监测"),
        Cell("数据", "这一列主要防什么", "传输与存储被窃取、敏感字段未脱敏"),
        Cell("数据", "落到什么技术", "加密、脱敏、访问控制"),
      ],
      note: "纵向五个对象、横向五个属性，交叉格填具体技术：属性定义保护到什么程度，对象定义保护谁。",
    ),
    Hyperedge(
      id: "he-five-threats",
      kind: Flow,
      label: "五类威胁：串联成链，IT 进 OT 出",
      roles: [
        Role("链", [
          "network-security",
          "app-security",
          "control-security",
          "device-security",
          "data-security",
        ]),
      ],
      result: None,
      cells: [],
      note: "入口在网络层或应用层，后果落在控制层与设备层；任一层失守，攻击者可用该层权限横向移动到相邻层。",
    ),
    Hyperedge(
      id: "he-control-choice",
      kind: Selection,
      label: "PLC / DCS / SCADA：按控制对象选",
      roles: [
        Role("控制对象", ["plc", "dcs", "scada"]),
      ],
      result: None,
      cells: [
        Cell("PLC", "对象范围", "单机、单设备，装置级控制"),
        Cell("PLC", "判据", "做具体逻辑与顺序控制，常作为 DCS/SCADA 的组成部分"),
        Cell("DCS", "对象范围", "同一地理位置的生产系统"),
        Cell("DCS", "判据", "回路分散、监控集中"),
        Cell("SCADA", "对象范围", "测控点分散、距离远、跨厂站"),
        Cell("SCADA", "判据", "主站＋多子站，经广域网通信"),
      ],
      note: "判据只有一条：控制对象是否地理集中。",
    ),
    Hyperedge(
      id: "he-carrier-choice",
      kind: Selection,
      label: "标识载体选型：要不要实时状态",
      roles: [
        Role("载体", ["passive-carrier", "active-carrier"]),
      ],
      result: None,
      cells: [
        Cell("被动载体", "能力", "无供电、无通信，只能被外部读取"),
        Cell("被动载体", "代价与难点", "成本极低、寿命等同印刷；唯一性与防复制难"),
        Cell("被动载体", "什么时候选它", "只需要身份，不需要运行状态"),
        Cell("主动载体", "能力", "自带供电与通信，可主动联网上报"),
        Cell("主动载体", "代价与难点", "供电、成本、维护；联网即扩大攻击面"),
        Cell("主动载体", "什么时候选它", "要追「这把刀装在哪台机床上」这类实时状态"),
      ],
      note: "选型判据只有一条：是否需要实时状态。",
    ),
    Hyperedge(
      id: "he-wireless-choice",
      kind: Selection,
      label: "无线选型：先找瓶颈，再让一步",
      roles: [
        Role("瓶颈", [
          "latency",
          "bandwidth",
          "power-budget",
          "connection-density",
        ]),
        Role("技术", ["5g", "lpwan"]),
      ],
      result: None,
      cells: [
        Cell("自动驾驶", "瓶颈", "时延与可靠性（1 ms、99.9999%）"),
        Cell("自动驾驶", "可以让步", "带宽：几 Mbit/s 够用"),
        Cell("自动驾驶", "选定的技术", "5G uRLLC"),
        Cell("远程医疗影像", "瓶颈", "带宽（百 Mbit/s 以上）"),
        Cell("远程医疗影像", "可以让步", "时延：100 ms 可接受"),
        Cell("远程医疗影像", "选定的技术", "5G eMBB"),
        Cell("电表、阀门、表计", "瓶颈", "功耗与覆盖"),
        Cell("电表、阀门、表计", "可以让步", "速率：几 kbit/s；时延：分钟级无所谓"),
        Cell("电表、阀门、表计", "选定的技术", "LPWAN（NB-IoT / LoRa）"),
        Cell("车间 AGV 视频回传", "瓶颈", "带宽与移动性"),
        Cell("车间 AGV 视频回传", "可以让步", "可靠性：可容忍重传"),
        Cell("车间 AGV 视频回传", "选定的技术", "WiFi 6 / 5G eMBB"),
        Cell("产线闭环控制", "瓶颈", "时延上界与抖动"),
        Cell("产线闭环控制", "可以让步", "移动性：设备不动，可以拉线"),
        Cell("产线闭环控制", "选定的技术", "TSN / 工业以太网"),
      ],
      note: "四个指标没有量纲就选不出东西，必须还原成数值、单位与测量口径。",
    ),
    Hyperedge(
      id: "he-cloud-modes",
      kind: Matrix,
      label: "云三模式：抽象层次与自主权",
      roles: [
        Role("云", ["cloud-computing"]),
      ],
      result: None,
      cells: [
        Cell("IaaS", "给什么", "裸机与磁盘等基础资源，可动态申请释放、按量计费"),
        Cell("IaaS", "用户要管什么", "操作系统以上全部自己装"),
        Cell("IaaS", "自主权", "最大"),
        Cell("PaaS", "给什么", "应用程序的运行环境，平台代管弹性与容错"),
        Cell("PaaS", "用户要管什么", "只能用特定编程环境与编程模型"),
        Cell("PaaS", "自主权", "中等"),
        Cell("SaaS", "给什么", "特定应用软件的功能"),
        Cell("SaaS", "用户要管什么", "无运行自定义程序的环境"),
        Cell("SaaS", "自主权", "最小"),
      ],
      note: "为什么有了 IaaS 还要 PaaS：IaaS 只给裸机，扩缩容、容错、环境部署仍由用户承担。",
    ),
    Hyperedge(
      id: "he-cps-levels",
      kind: Matrix,
      label: "CPS 三层：判据是互联手段",
      roles: [
        Role("实例", ["plc", "dcs", "scada", "industrial-platform"]),
      ],
      result: None,
      cells: [
        Cell("单元级", "互联手段", "无：单个物理实体的闭环"),
        Cell("单元级", "覆盖与例子", "一个实体、最小数据闭环；PLC 控制单元、数控机床、机器人"),
        Cell("系统级", "互联手段", "工业网络"),
        Cell("系统级", "覆盖与例子", "多个单元级构成产线／车间／工厂；DCS、SCADA、智能生产线"),
        Cell("SoS 级", "互联手段", "大数据平台"),
        Cell("SoS 级", "覆盖与例子", "跨系统、跨平台、多源异构集成；工业云、大数据平台"),
      ],
      note: "判据一句话：互联靠工业网络的是系统级，靠大数据平台跨系统集成的是 SoS 级。",
    ),
    Hyperedge(
      id: "he-arch-evolution",
      kind: Evolution,
      label: "体系架构 1.0 → 2.0：换的是名字",
      roles: [
        Role("版本", ["arch-1.0", "arch-2.0"]),
      ],
      result: None,
      cells: [
        Cell("1.0（2016）", "三大核心", "网络、数据、安全"),
        Cell("1.0（2016）", "改动", "应用侧给出三大优化闭环"),
        Cell("2.0（2019）", "三大核心", "网络、平台、安全"),
        Cell("2.0（2019）", "改动", "以平台替换数据：数据功能重叠，职责切不开"),
      ],
      note: "换的只是名字：把「数据」从体系名变成平台体系内部的职责，数据仍是核心要素。",
    ),
    Hyperedge(
      id: "he-deployment",
      kind: Mapping,
      label: "三体系 → 四实施系统",
      roles: [
        Role("体系", ["network-system", "platform-system", "security-framework"]),
      ],
      result: Some("deployment-systems"),
      cells: [
        Cell("网络体系", "落成的系统", "网络系统 ＋ 标识系统（标识解析单独立项）"),
        Cell("平台体系", "落成的系统", "平台系统"),
        Cell("安全体系", "落成的系统", "安全系统"),
      ],
      note: "3 体系变 4 系统，多出来的是标识：它是「名字对不上」这个问题的根，必须独立建设、独立验收。",
    ),
    Hyperedge(
      id: "he-extranet",
      kind: Matrix,
      label: "工厂外网：三专线一连接",
      roles: [
        Role("专线", ["mpls-vpn", "otn"]),
        Role("网络", ["factory-extranet", "sdn-wan"]),
      ],
      result: None,
      cells: [
        Cell("上网专线", "对端", "公网"),
        Cell("上网专线", "核心需求", "访问互联网资源"),
        Cell("上网专线", "承载", "IP、Ethernet、ATM、SDH/SONET"),
        Cell("互联专线", "对端", "异地厂区、分支机构"),
        Cell("互联专线", "核心需求", "端到端隔离与可预期时延"),
        Cell("互联专线", "承载", "MPLS VPN、基于 OTN 的光网专线、SD-WAN"),
        Cell("上云专线", "对端", "工业云数据中心"),
        Cell("上云专线", "核心需求", "大带宽、低成本入云"),
        Cell("上云专线", "承载", "Cloud VPN（入云总线）"),
        Cell("上网连接", "对端", "出厂产品、移动作业"),
        Cell("上网连接", "核心需求", "移动性与广覆盖"),
        Cell("上网连接", "承载", "LTE、NB-IoT、5G"),
      ],
      note: "分类依据是对端是谁；MPLS 做灵活互联，OTN 做重载骨干。",
    ),
    Hyperedge(
      id: "he-blockchain",
      kind: Matrix,
      label: "工业区块链：四难题对四方案",
      roles: [
        Role("难题", ["industrial-blockchain"]),
        Role("技术", ["blockchain"]),
      ],
      result: None,
      cells: [
        Cell("信任构建难", "方案", "联盟数字身份：按场景签发多个联盟身份 ID 与凭证"),
        Cell("信任构建难", "机制", "身份自生成、自存储、自销毁，覆盖人机物全生命周期"),
        Cell("确权流转难", "方案", "资产标签上链、链上链下绑定"),
        Cell("确权流转难", "机制", "隔离通道加流转共识的访问控制，路径与责任人可核"),
        Cell("安全共享难", "方案", "多方密文同态计算"),
        Cell("安全共享难", "机制", "密文上直接计算，解密后与明文结果一致，数据可用不可见"),
        Cell("审计追溯难", "方案", "链上事件映射加智能合约"),
        Cell("审计追溯难", "机制", "事件行为簇按时间打包成审计报告，规则上链自动执行"),
      ],
      note: "四件技术基础各管一段：数字签名管身份、时间戳定序、共识与多方存储防单方改写、智能合约自动执行。",
    ),
    ..binary_edges()
  ]
}

// 二元边 -----------------------------------------------------------------
//
// 六类二元边把节点连成网：上位、组成、依赖、细化、度量、对照。
// 结构超边给出矩阵、选型与流程，这里补上节点之间的关系，
// 让「从概念跳到关系」在任何一个节点上都走得通。

fn binary(
  id: String,
  kind: EdgeKind,
  from: String,
  to: String,
  note: String,
) -> Hyperedge {
  let names = role_names(kind)
  Hyperedge(
    id: id,
    kind: kind,
    label: concept_name(from) <> " → " <> concept_name(to),
    roles: [Role(names.0, [from]), Role(names.1, [to])],
    result: None,
    cells: [],
    note: note,
  )
}

fn binary_edges() -> List(Hyperedge) {
  [
    // 上位：谁是谁的一种
    binary("e-iiot-iot", IsA, "iiot", "iot", "工业物联网是物联网的子集，集中在生产力方面。"),
    binary(
      "e-iep-ie",
      IsA,
      "ie-protocols",
      "industrial-ethernet",
      "四种协议都是工业以太网的具体实现。",
    ),
    binary(
      "e-tsn-ie",
      IsA,
      "tsn",
      "industrial-ethernet",
      "TSN 是 802.1 的一组以太网增强标准，仍跑在以太网帧上。",
    ),
    binary(
      "e-smartsensor-sensor",
      IsA,
      "smart-sensor",
      "sensor",
      "智能传感器是传感器智能化的产物，由传感模块、智能处理模块、通信模块组成。",
    ),
    binary(
      "e-plc-cps",
      IsA,
      "plc",
      "cps",
      "PLC 是单元级 CPS 的典型实例：感知、计算、控制自成一个小闭环。",
    ),

    // 组成：谁是谁的一部分
    binary(
      "e-sensing-iot",
      PartOf,
      "sensing-layer",
      "iot-architecture",
      "三层架构的最底层，负责状态获取与辨识。",
    ),
    binary(
      "e-network-iot",
      PartOf,
      "network-layer",
      "iot-architecture",
      "三层架构的中枢，只保证送达、不解释语义。",
    ),
    binary(
      "e-app-iot",
      PartOf,
      "application-layer",
      "iot-architecture",
      "三层架构的顶层，云与大数据在这里落到业务。",
    ),
    binary(
      "e-sensor-sensing",
      PartOf,
      "sensor",
      "sensing-layer",
      "传感器是感知层里回答「是多少」的那一类设备。",
    ),
    binary(
      "e-rfid-sensing",
      PartOf,
      "rfid",
      "sensing-layer",
      "RFID 属识别设备，给物体贴标签、回答「是哪一个」。",
    ),
    binary(
      "e-wsn-network",
      PartOf,
      "wsn",
      "network-layer",
      "WSN 解决末端组网与回传，是网络层最靠现场的一段。",
    ),
    binary(
      "e-fieldbus-network",
      PartOf,
      "fieldbus",
      "network-layer",
      "现场总线是有线连接技术的两大体系之一。",
    ),
    binary(
      "e-ie-network",
      PartOf,
      "industrial-ethernet",
      "network-layer",
      "工业以太网与现场总线并列，构成有线连接的另一半。",
    ),
    binary(
      "e-edge-layer-ps",
      PartOf,
      "edge-layer",
      "platform-system",
      "平台体系的最底层，构建数据基础。",
    ),
    binary(
      "e-platform-layer-ps",
      PartOf,
      "platform-layer",
      "platform-system",
      "平台体系的核心层，模型与微服务在此沉淀。",
    ),
    binary("e-plc-device", PartOf, "plc", "layer-device", "PLC 属于设备层的典型系统。"),
    binary(
      "e-dcs-factory",
      PartOf,
      "dcs",
      "layer-factory",
      "DCS 是同一厂区内分散控制、集中管理的系统级 CPS。",
    ),
    binary(
      "e-scada-factory",
      PartOf,
      "scada",
      "layer-factory",
      "SCADA 面向跨厂站测点，落在工厂层往上的一段。",
    ),
    binary(
      "e-mpls-extranet",
      PartOf,
      "mpls-vpn",
      "factory-extranet",
      "互联专线的一种承载方式，做灵活互联。",
    ),
    binary(
      "e-otn-extranet",
      PartOf,
      "otn",
      "factory-extranet",
      "互联专线的另一种承载方式，做重载骨干。",
    ),
    binary(
      "e-sdn-extranet",
      PartOf,
      "sdn-wan",
      "factory-extranet",
      "SD-WAN 把多链路编排叠加在互联专线上。",
    ),
    binary(
      "e-intranet-ns",
      PartOf,
      "factory-intranet",
      "network-system",
      "工厂内网络是网络互联在厂内的那一段。",
    ),
    binary(
      "e-extranet-ns",
      PartOf,
      "factory-extranet",
      "network-system",
      "工厂外网络是网络互联在厂外的那一段。",
    ),
    binary(
      "e-itot-intranet",
      PartOf,
      "it-ot",
      "factory-intranet",
      "两层三级里的那两层就是 IT 与 OT。",
    ),
    binary(
      "e-boards-arch",
      PartOf,
      "three-boards",
      "arch-2.0",
      "三大板块是 2.0 的设计方法，三体系是设计出来的内容。",
    ),
    binary(
      "e-bv-boards",
      PartOf,
      "business-view",
      "three-boards",
      "设计链的第一段：商业目标与业务需求。",
    ),
    binary(
      "e-fa-boards",
      PartOf,
      "functional-arch",
      "three-boards",
      "设计链的第二段：系统功能定义。",
    ),
    binary(
      "e-ds-boards",
      PartOf,
      "deployment-systems",
      "three-boards",
      "设计链的第三段：实施部署方式。",
    ),
    binary(
      "e-3s-arch",
      PartOf,
      "three-systems",
      "arch-2.0",
      "2.0 继承 1.0 的三大功能体系。",
    ),
    binary(
      "e-attrs-framework",
      PartOf,
      "safety-attributes",
      "security-framework",
      "五个属性是框架的纵轴，定义保护到什么程度。",
    ),
    binary(
      "e-dims-framework",
      PartOf,
      "security-dimensions",
      "security-framework",
      "五个对象是框架的横轴，定义保护谁。",
    ),
    binary(
      "e-rfid-sensingtech",
      PartOf,
      "rfid",
      "sensing-tech",
      "感知技术三类中的「认身份」。",
    ),
    binary(
      "e-mv-sensingtech",
      PartOf,
      "machine-vision",
      "sensing-tech",
      "感知技术三类中的「看外观」。",
    ),
    binary(
      "e-cps-techarch",
      PartOf,
      "cps",
      "platform-tech-arch",
      "CPS 与控制系统属使能技术。",
    ),
    binary(
      "e-dt-techarch",
      PartOf,
      "digital-twin",
      "platform-tech-arch",
      "数字孪生属使能技术，是核心功能原理的落地形态。",
    ),
    binary(
      "e-bdf-bigdata",
      PartOf,
      "bigdata-features",
      "industrial-bigdata",
      "4V 与五项扩展是它的特征描述。",
    ),
    binary(
      "e-bda-bigdata",
      PartOf,
      "bigdata-arch",
      "industrial-bigdata",
      "功能体系是它的技术分层。",
    ),
    binary(
      "e-kg-bda",
      PartOf,
      "knowledge-graph",
      "bigdata-arch",
      "知识图谱是建模分析层的三种分析技术之一。",
    ),
    binary(
      "e-modalb-bigdata",
      PartOf,
      "multi-modal",
      "industrial-bigdata",
      "形态划分决定存储引擎怎么选。",
    ),
    binary(
      "e-principle-fa",
      PartOf,
      "core-principle",
      "functional-arch",
      "核心功能原理是功能架构那一节给出的总纲。",
    ),
    binary(
      "e-essence-ii",
      PartOf,
      "ii-essence",
      "industrial-internet",
      "本质与核心是对定义的一句话收束。",
    ),
    binary(
      "e-features-ii",
      PartOf,
      "ii-features",
      "industrial-internet",
      "三大特点是对它提出的网络要求。",
    ),
    binary(
      "e-vs-ii",
      PartOf,
      "ii-vs-internet",
      "industrial-internet",
      "四栏区别把定义放到与消费互联网的对照里。",
    ),
    binary(
      "e-status-ii",
      PartOf,
      "ii-status",
      "industrial-internet",
      "四方向成果是它的发展现状。",
    ),
    binary("e-iiotsix-iiot", PartOf, "iiot-six", "iiot", "六大特征是工业物联网的能力链。"),
    binary(
      "e-stages-smart",
      PartOf,
      "three-stages",
      "smart-manufacturing",
      "三阶段是智能制造自身的演进路线。",
    ),
    binary(
      "e-cm-apps",
      PartOf,
      "cloud-manufacturing",
      "platform-apps",
      "云制造是三个应用方向里作用范围最广的一个。",
    ),

    // 细化：后一章把前一章讲清楚
    binary(
      "e-clouddeploy-refines",
      Refines,
      "cloud-deploy",
      "cloud-computing",
      "第五章把第二章的服务模式细化到部署模型与私有云的弹性代价。",
    ),
    binary(
      "e-edgecloud-refines",
      Refines,
      "edge-cloud-collab",
      "edge-computing",
      "第五章把第四章的边缘计算细化到边与云的分工。",
    ),
    binary("e-dt-cps", Refines, "digital-twin", "cps", "数字孪生是 CPS 在具体对象上的落地形态。"),
    binary(
      "e-di-ni",
      Refines,
      "data-interchange",
      "network-interconnect",
      "链路通了不等于听得懂，数据互通细化网络互联。",
    ),
    binary(
      "e-shift-dims",
      Refines,
      "dimension-shift",
      "security-dimensions",
      "第六章把五个维度落到各自变了什么、因此带来什么挑战。",
    ),

    // 依赖：缺了前一个，后一个不成立
    binary(
      "e-idres-id",
      Requires,
      "id-resolution",
      "identifier",
      "没有编码就没有可解析的名字。",
    ),
    binary(
      "e-idres-nodes",
      Requires,
      "id-resolution",
      "parse-hierarchy",
      "解析要沿节点层级逐级寻址。",
    ),
    binary(
      "e-iiot-iotarch",
      Requires,
      "iiot",
      "iot-architecture",
      "工业物联网建立在感知、网络、应用三层之上，再叠加工业过程约束。",
    ),
    binary(
      "e-pl-requires-el",
      Requires,
      "platform-layer",
      "edge-layer",
      "平台层的数据来自边缘层的接入与预处理。",
    ),
    binary(
      "e-cm-requires-3p",
      Requires,
      "cloud-manufacturing",
      "three-platforms",
      "服务云池要靠平台把资源与能力服务化。",
    ),
    binary(
      "e-smart-requires-ii",
      Requires,
      "smart-manufacturing",
      "industrial-internet",
      "工业互联网是依托基础，智能制造是最终目标。",
    ),
    binary(
      "e-apps-requires-platform",
      Requires,
      "platform-apps",
      "industrial-platform",
      "三个应用方向都是平台能力的出口。",
    ),
    binary(
      "e-3p-requires-platform",
      Requires,
      "three-platforms",
      "industrial-platform",
      "三家都是这个定义下的具体实现。",
    ),
    binary(
      "e-interop-requires-di",
      Requires,
      "protocol-interop",
      "data-interchange",
      "协议互通最后都要落到统一信息模型，否则只换了封装。",
    ),
    binary(
      "e-discrete-requires-plc",
      Requires,
      "discrete-process",
      "plc",
      "离散制造按工单与批次走工序，逻辑与顺序控制靠 PLC。",
    ),

    // 度量：前一个在量后一个
    binary(
      "e-oee-factory",
      Measures,
      "oee",
      "layer-factory",
      "OEE 度量工厂层的产出效率，三个乘数分别对应停机、速度与质量。",
    ),

    // 对照：成对出现，判据一句话
    binary(
      "e-fieldbus-ie",
      Contrasts,
      "fieldbus",
      "industrial-ethernet",
      "判据是是否沿用标准以太网的帧格式与物理层；两者并列，不是替代关系。",
    ),
    binary(
      "e-tc-zt",
      Contrasts,
      "trusted-computing",
      "zero-trust",
      "可信计算度量平台完整性，零信任逐次验证访问请求。",
    ),
    binary(
      "e-el-edgecomp",
      Contrasts,
      "edge-layer",
      "edge-computing",
      "层说的是位置，计算说的是能力：同一块地方的两个方面。",
    ),
    binary(
      "e-dims-threats",
      Contrasts,
      "security-dimensions",
      "threat-five",
      "同一组对象的两个视角：一个说保护谁，一个说攻击从哪进。",
    ),
    binary("e-mpls-otn", Contrasts, "mpls-vpn", "otn", "MPLS 做灵活互联，OTN 做重载骨干。"),
  ]
}

// 查询 -------------------------------------------------------------------

pub fn find_concept(graph: Graph, id: String) -> Option(Concept) {
  list.find(graph.concepts, fn(concept) { concept.id == id })
  |> from_result
}

pub fn tested(concept: Concept) -> Bool {
  !list.is_empty(concept.questions)
}

pub fn hyperedge_members(edge: Hyperedge) -> List(String) {
  let members = edge.roles |> list.flat_map(fn(role) { role.members })
  case edge.result {
    Some(id) -> list.unique(list.append(members, [id]))
    None -> list.unique(members)
  }
}

pub fn hyperedges_of(graph: Graph, id: String) -> List(Hyperedge) {
  list.filter(graph.hyperedges, fn(edge) {
    list.contains(hyperedge_members(edge), id)
  })
}

// 表格型超边的行列：都按作者顺序去重，渲染时不再排序。
pub fn cell_columns(edge: Hyperedge) -> List(String) {
  edge.cells |> list.map(fn(cell) { cell.col }) |> list.unique
}

pub fn cell_rows(edge: Hyperedge) -> List(String) {
  edge.cells |> list.map(fn(cell) { cell.row }) |> list.unique
}

pub fn cell_text(edge: Hyperedge, row: String, col: String) -> String {
  case list.find(edge.cells, fn(cell) { cell.row == row && cell.col == col }) {
    Ok(cell) -> cell.text
    Error(_) -> ""
  }
}

// 规范名、id、别名都参与子串匹配；空查询不返回任何命中。
pub fn search(graph: Graph, query: String) -> List(String) {
  let needle = query |> string.trim |> string.lowercase
  case needle {
    "" -> []
    _ ->
      graph.concepts
      |> list.filter(fn(concept) { matches(concept, needle) })
      |> list.map(fn(concept) { concept.id })
  }
}

fn matches(concept: Concept, needle: String) -> Bool {
  string.contains(string.lowercase(concept.name), needle)
  || string.contains(string.lowercase(concept.id), needle)
  || list.any(concept.aliases, fn(alias) {
    string.contains(string.lowercase(alias), needle)
  })
}

pub fn visible_ids(
  graph: Graph,
  enabled: List(String),
  only_tested: Bool,
) -> List(String) {
  graph.concepts
  |> list.filter(fn(concept) {
    list.contains(enabled, cluster_id(concept.cluster))
    && case only_tested {
      True -> tested(concept)
      False -> True
    }
  })
  |> list.map(fn(concept) { concept.id })
}

// 引用完整性：超边里出现、但没有对应概念节点的 id。
pub fn dangling_refs(graph: Graph) -> List(String) {
  let ids = list.map(graph.concepts, fn(concept) { concept.id })
  graph.hyperedges
  |> list.flat_map(fn(edge) { hyperedge_members(edge) })
  |> list.filter(fn(id) { !list.contains(ids, id) })
  |> list.unique
}

// 孤点：没有出现在任何一条关系里的概念。
pub fn orphan_ids(graph: Graph) -> List(String) {
  let linked =
    graph.hyperedges
    |> list.flat_map(fn(edge) { hyperedge_members(edge) })
    |> list.unique

  graph.concepts
  |> list.map(fn(concept) { concept.id })
  |> list.filter(fn(id) { !list.contains(linked, id) })
}

pub fn duplicate_ids(graph: Graph) -> List(String) {
  let #(_, duplicates) =
    list.fold(
      list.map(graph.concepts, fn(concept) { concept.id }),
      #([], []),
      fn(state, id) {
        let #(seen, found) = state
        case list.contains(seen, id) {
          True -> #(seen, [id, ..found])
          False -> #([id, ..seen], found)
        }
      },
    )
  duplicates
}

// 序列化给画布：一次给全图，之后的更新只传状态。
pub fn to_json(graph: Graph) -> String {
  json.object([
    #(
      "clusters",
      json.array(from: all_clusters(), of: fn(cluster) {
        json.object([
          #("id", json.string(cluster_id(cluster))),
          #("label", json.string(cluster_label(cluster))),
        ])
      }),
    ),
    #("concepts", json.array(from: graph.concepts, of: concept_json)),
    #("hyperedges", json.array(from: graph.hyperedges, of: hyperedge_json)),
  ])
  |> json.to_string
}

fn concept_json(concept: Concept) -> json.Json {
  json.object([
    #("id", json.string(concept.id)),
    #("name", json.string(concept.name)),
    #("aliases", json.array(from: concept.aliases, of: json.string)),
    #("cluster", json.string(cluster_id(concept.cluster))),
    #("tested", json.bool(tested(concept))),
  ])
}

fn hyperedge_json(edge: Hyperedge) -> json.Json {
  json.object([
    #("id", json.string(edge.id)),
    #("label", json.string(edge.label)),
    #("kind", json.string(edge_kind_label(edge.kind))),
    #("members", json.array(from: hyperedge_members(edge), of: json.string)),
    #("binary", json.bool(is_binary(edge))),
    #("result", json.nullable(from: edge.result, of: json.string)),
  ])
}

// 静态总表 ---------------------------------------------------------------
//
// 打印与无 JS 时看的那两张表，与图出自同一份数据。概念表在前、关系表在后：
// 关掉脚本之后，12 格能力矩阵、选型表与题号都只能靠这里读。

pub fn static_table() -> String {
  concept_table() <> "\n" <> relations_table()
}

fn concept_table() -> String {
  // 不排序：数据本身按簇与叙事顺序排，静态表因此和画布上的列一一对应。
  let rows = graph().concepts |> list.map(row_html) |> string.concat

  "<table class=\"concept-table\">\n"
  <> "<thead>\n<tr><th>簇</th><th>概念</th><th>定义</th><th>机制</th><th>题号</th></tr>\n</thead>\n"
  <> "<tbody>\n"
  <> rows
  <> "</tbody>\n</table>"
}

fn relations_table() -> String {
  let rows =
    graph().hyperedges
    |> list.map(edge_row_html)
    |> string.concat

  "<h3 id=\"relations\">关系总表</h3>\n"
  <> "<table class=\"concept-table relation-table\">\n"
  <> "<thead>\n<tr><th>类型</th><th>关系</th><th>成员</th><th>说明</th></tr>\n</thead>\n"
  <> "<tbody>\n"
  <> rows
  <> "</tbody>\n</table>"
}

fn edge_row_html(edge: Hyperedge) -> String {
  "<tr><td>"
  <> escape(edge_kind_label(edge.kind))
  <> "</td><td>"
  <> escape(edge.label)
  <> "</td><td>"
  <> edge_roles_html(edge)
  <> edge_result_html(edge)
  <> "</td><td>"
  <> escape(edge.note)
  <> edge_cells_html(edge)
  <> "</td></tr>\n"
}

fn edge_roles_html(edge: Hyperedge) -> String {
  edge.roles
  |> list.map(fn(role) {
    "<span class=\"edge-role\">"
    <> escape(role.name)
    <> "：</span>"
    <> members_html(role.members)
  })
  |> string.join("")
}

fn edge_result_html(edge: Hyperedge) -> String {
  case edge.result {
    Some(id) -> "<span class=\"edge-role\">结果：</span>" <> members_html([id])
    None -> ""
  }
}

fn edge_cells_html(edge: Hyperedge) -> String {
  case edge.cells {
    [] -> ""
    _ -> {
      let columns = cell_columns(edge)
      let head =
        list.map(columns, fn(col) { "<th>" <> escape(col) <> "</th>" })
        |> string.concat
      let rows =
        cell_rows(edge)
        |> list.map(fn(row) {
          let cells =
            list.map(columns, fn(col) {
              "<td>" <> escape(cell_text(edge, row, col)) <> "</td>"
            })
            |> string.concat
          "<tr><th scope=\"row\">"
          <> escape(row)
          <> "</th>"
          <> cells
          <> "</tr>\n"
        })
        |> string.concat
      "\n<table class=\"concept-table edge-cells\">\n<thead>\n<tr><th></th>"
      <> head
      <> "</tr>\n</thead>\n<tbody>\n"
      <> rows
      <> "</tbody>\n</table>"
    }
  }
}

fn members_html(ids: List(String)) -> String {
  ids
  |> list.map(fn(id) {
    "<span class=\"edge-member\">" <> escape(name_of(id)) <> "</span>"
  })
  |> string.join("、")
}

fn name_of(id: String) -> String {
  concept_name(id)
}

// 只用概念表，不经过 graph()：构造超边标签时调用它，走 graph() 会自递归。
pub fn concept_name(id: String) -> String {
  case list.find(concepts(), fn(concept) { concept.id == id }) {
    Ok(concept) -> concept.name
    Error(_) -> id <> "（缺失）"
  }
}

fn row_html(concept: Concept) -> String {
  "<tr>"
  <> "<td>"
  <> escape(cluster_label(concept.cluster))
  <> "</td>"
  <> "<td>"
  <> "<a href=\""
  <> escape(concept.chapter)
  <> "\">"
  <> escape(concept.name)
  <> "</a>"
  <> caliber_html(concept)
  <> "</td>"
  <> "<td>"
  <> escape(concept.def)
  <> "</td>"
  <> "<td>"
  <> escape(concept.mechanism)
  <> "</td>"
  <> "<td>"
  <> questions_html(concept)
  <> "</td>"
  <> "</tr>\n"
}

fn caliber_html(concept: Concept) -> String {
  case concept.caliber {
    "" -> ""
    caliber -> "<span class=\"caliber\">口径：" <> escape(caliber) <> "</span>"
  }
}

fn questions_html(concept: Concept) -> String {
  concept.questions
  |> list.map(fn(question) {
    "<a href=\""
    <> escape(question_href(question))
    <> "\" title=\""
    <> escape(question_label(question))
    <> "\">"
    <> escape(question_id(question))
    <> "</a>"
  })
  |> string.join("、")
}

fn escape(text: String) -> String {
  text
  |> string.replace("&", "&amp;")
  |> string.replace("<", "&lt;")
  |> string.replace(">", "&gt;")
  |> string.replace("\"", "&quot;")
}
