//! 雷达 widget。两个变体并存：
//!   sweep — 扫描臂 4.5s/圈 + 同心圆 + 罗盘 NESW
//!   pulse — 设备点呼吸 halo（2.6s 周期）
//! 字符 fallback：unicode 模式用 braille / dot marker，ascii 模式用 Dot。

use crate::mock::Device;
use crate::ui::theme::{CharTier, Theme};
use ratatui::layout::Rect;
use ratatui::style::{Color, Modifier, Style};
use ratatui::symbols::Marker;
use ratatui::text::{Line, Span};
use ratatui::widgets::canvas::{Canvas, Context};
use ratatui::widgets::{Block, BorderType, Borders};
use ratatui::Frame;
use std::f64::consts::PI;
use std::time::Instant;

pub fn render(
    f: &mut Frame,
    area: Rect,
    theme: &Theme,
    devices: &[Device],
    selected_idx: Option<usize>,
    start: Instant,
) {
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(theme.line()))
        .title(Line::from(vec![
            Span::raw(" "),
            Span::styled("RADAR", Style::default().fg(theme.lime_deep()).add_modifier(Modifier::BOLD)),
            Span::styled(format!("  {}  雷达 ", theme.small_dot()), Style::default().fg(theme.muted())),
            Span::styled(format!("[{}]", theme.label_color_tier()), Style::default().fg(theme.muted())),
            Span::raw(" "),
        ]));

    let marker = match theme.chars {
        CharTier::Full => Marker::Braille,
        CharTier::Ascii => Marker::Dot,
    };

    let ink = theme.ink();
    let muted = theme.muted();
    let lime = theme.lime();
    let lime_deep = theme.lime_deep();
    let flame = theme.flame();

    let elapsed = start.elapsed().as_secs_f64();
    let sweep_period = 4.5_f64;
    let sweep_angle = (elapsed % sweep_period) / sweep_period * 2.0 * PI;
    let pulse_period = 2.6_f64;

    let devs: Vec<Device> = devices.to_vec();
    let selected = selected_idx;

    let canvas = Canvas::default()
        .block(block)
        .marker(marker)
        .x_bounds([-100.0, 100.0])
        .y_bounds([-100.0, 100.0])
        .paint(move |ctx| {
            paint_compass(ctx, muted);
            paint_rings(ctx, muted);
            paint_crosshair(ctx, muted);
            paint_sweep(ctx, sweep_angle, lime);
            paint_center(ctx, ink, lime_deep);

            for (i, d) in devs.iter().enumerate() {
                let r = (d.dist as f64).clamp(0.0, 1.0) * 80.0;
                let theta = (d.angle as f64).to_radians();
                let x = r * theta.cos();
                let y = r * theta.sin();
                let is_sel = selected == Some(i);

                // 呼吸 halo
                let phase = ((elapsed + (i as f64) * 0.3) % pulse_period) / pulse_period;
                let halo_r = 6.0 + 6.0 * (1.0 - phase);
                paint_circle(ctx, x, y, halo_r, if is_sel { flame } else { lime });

                // 中心 dot
                ctx.draw(&ratatui::widgets::canvas::Points {
                    coords: &[(x, y)],
                    color: if is_sel { flame } else { lime },
                });

                // selected 时画从中心到 dot 的 dashed line
                if is_sel {
                    paint_dashed(ctx, 0.0, 0.0, x, y, flame);
                }

                // label
                ctx.print(
                    x + 6.0,
                    y,
                    Line::from(vec![
                        Span::styled(
                            d.who,
                            Style::default()
                                .fg(if is_sel { flame } else { ink })
                                .add_modifier(Modifier::BOLD),
                        ),
                        Span::styled(
                            format!(" {}ms", d.rtt_ms),
                            Style::default().fg(muted),
                        ),
                    ]),
                );
            }
        });

    f.render_widget(canvas, area);
}

fn paint_compass(ctx: &mut Context, c: Color) {
    let s = Style::default().fg(c).add_modifier(Modifier::BOLD);
    ctx.print(-3.0,  92.0, Span::styled("N", s));
    ctx.print(-3.0, -92.0, Span::styled("S", s));
    ctx.print( 92.0,  0.0, Span::styled("E", s));
    ctx.print(-95.0,  0.0, Span::styled("W", s));
}

fn paint_rings(ctx: &mut Context, c: Color) {
    for r in [27.0, 54.0, 81.0] {
        ring(ctx, 0.0, 0.0, r, c, 80);
    }
}

fn paint_crosshair(ctx: &mut Context, c: Color) {
    // 中心轻十字（不画到边缘，避免与圆环视觉冲突）
    let n = 60;
    for i in 0..n {
        let t = (i as f64 / n as f64) * 2.0 - 1.0;
        let r = t * 78.0;
        ctx.draw(&ratatui::widgets::canvas::Points { coords: &[(r, 0.0)], color: c });
        ctx.draw(&ratatui::widgets::canvas::Points { coords: &[(0.0, r)], color: c });
    }
}

fn paint_sweep(ctx: &mut Context, angle: f64, c: Color) {
    // 扫描臂：3 段不同亮度的射线模拟"渐变拖尾"
    for k in 0..40 {
        let r = (k as f64 / 40.0) * 80.0;
        let a = angle;
        let x = r * a.cos();
        let y = r * a.sin();
        ctx.draw(&ratatui::widgets::canvas::Points { coords: &[(x, y)], color: c });
    }
    // 拖尾：稍微偏后的两条短线
    for offset in [0.08_f64, 0.16_f64] {
        let a = angle - offset;
        for k in 0..28 {
            let r = (k as f64 / 28.0) * 70.0;
            let x = r * a.cos();
            let y = r * a.sin();
            ctx.draw(&ratatui::widgets::canvas::Points { coords: &[(x, y)], color: c });
        }
    }
}

fn paint_center(ctx: &mut Context, ink: Color, accent: Color) {
    // 中心 6×6 实心块 + YOU 字样
    for dx in -5..=5 {
        for dy in -3..=3 {
            ctx.draw(&ratatui::widgets::canvas::Points {
                coords: &[(dx as f64, dy as f64)],
                color: ink,
            });
        }
    }
    ctx.print(
        -3.0,
        0.0,
        Span::styled("YOU", Style::default().fg(accent).add_modifier(Modifier::BOLD)),
    );
}

fn ring(ctx: &mut Context, cx: f64, cy: f64, r: f64, c: Color, steps: usize) {
    for i in 0..steps {
        let t = (i as f64 / steps as f64) * 2.0 * PI;
        let x = cx + r * t.cos();
        let y = cy + r * t.sin();
        ctx.draw(&ratatui::widgets::canvas::Points {
            coords: &[(x, y)],
            color: c,
        });
    }
}

fn paint_circle(ctx: &mut Context, cx: f64, cy: f64, r: f64, c: Color) {
    ring(ctx, cx, cy, r, c, 36);
}

fn paint_dashed(ctx: &mut Context, x0: f64, y0: f64, x1: f64, y1: f64, c: Color) {
    let dx = x1 - x0;
    let dy = y1 - y0;
    let dist = (dx * dx + dy * dy).sqrt();
    let n = (dist / 2.0) as usize;
    for i in 0..n {
        if i % 3 == 0 {
            let t = i as f64 / n as f64;
            let x = x0 + dx * t;
            let y = y0 + dy * t;
            ctx.draw(&ratatui::widgets::canvas::Points {
                coords: &[(x, y)],
                color: c,
            });
        }
    }
}
