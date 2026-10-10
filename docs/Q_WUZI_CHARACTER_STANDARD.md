 1 | # Q 版舞梓角色标准
 2 | 
 3 | ## 最高规则
 4 | 
 5 | 现有 分享区/Q版/master.png 是身份基准，不重新设计角色。
 6 | 
 7 | 必须固定：蓝紫色长发、金橙色眼睛、狐狸面具、蓝/粉花饰、黑粉宽袖舞衣、腰部粉色大蝴蝶结、流苏挂饰、袜鞋，以及约 3.0–3.5 头身的 Q 版比例。
 8 | 
 9 | ## 统一画布

- 1024×1024 RGBA。
- 真透明背景。
- 固定脚底 baseline。
- 固定视觉中心。
- 完整角色不得切边。
- 原始高分辨率生成图保留，不覆盖。

## 核心身份视图

    identity/
    ├─ master_3q_front.png
    ├─ front.png
    ├─ left_profile.png
    ├─ right_profile.png
    ├─ back.png
    └─ back_3q.png

即使整体服装近似对称，也保留左右侧面，因为面具、发饰和头发遮挡具有视觉不对称。

## 结构姿态锚点

    poses/
    ├─ sit.png
    ├─ hands_forward.png
    ├─ crouch.png
    └─ lie.png

姿态图只负责结构约束，不直接当最终动画帧。

## 表情标准

    expressions/
    ├─ neutral.png
    ├─ blink_half.png
    ├─ blink_closed.png
    ├─ shy.png
    ├─ shocked.png
    ├─ happy.png
    └─ sleepy.png

## 一致性检查

每张新参考图必须检查：

1. 头身比例。
2. 脸型、眼距、眼睛颜色。
3. 面具方向和位置。
4. 花饰颜色、数量、位置。
5. 发长、发尾和刘海。
6. 宽袖连接位置。
7. 腰部蝴蝶结大小和高度。
8. 袜鞋结构。
9. 手部结构。
10. 透明边缘。
11. 缩小到约 200 px 高时的辨识度。

出现身份漂移时，重做该参考图，不允许让错误参考继续向后传播。

## 生成参考优先级

    现有 Q 版 master
        ↓
    成年舞梓三视图/高清立绘（确认真实服装结构）
        ↓
    2025 修复版参考（确认新版脸和细节）
        ↓
    上一张已审核通过的相邻角度参考

不要只依赖上一生成帧递推。

转身/转圈使用 master + front/profile/back/back_3q；坐下、吃东西和打游戏使用 master + 对应侧面 + sit/hands_forward；睡觉使用 master + profile + lie。

复杂动作的碗、筷子、手柄、床和被子优先作为独立道具制作。
