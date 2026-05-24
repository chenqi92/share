//! 截图模块：用 ratatui TestBackend 把指定 scene 渲染到内存 Buffer，
//! 然后把 Buffer 序列化成 SVG（每个 cell 一个 rect + text）。
//! 配合 `rsvg-convert` 或浏览器即可转 PNG，不需要真终端。
//!
//! 调用入口：`meshdrop-tui snapshot --scene <name> --out <path.svg> [--cols 140 --rows 42]`

use anyhow::Result;
use ratatui::backend::TestBackend;
use ratatui::buffer::{Buffer, Cell};
use ratatui::style::{Color, Modifier};
use ratatui::Terminal;
use std::path::Path;

const CELL_W: f32 = 9.0;   // 像素
const CELL_H: f32 = 18.0;
const FONT_SIZE: f32 = 14.0;
// 字体堆栈：先尝试 Geist Mono（设计稿用），fallback 到系统 mono
const FONT_STACK: &str = "'Geist Mono','SF Mono','JetBrains Mono','Menlo','Consolas',monospace";
// 暗底（PROMPT §5 暗模式 dink）
const BG_DEFAULT: &str = "#0E0C09";
// 主文字（dpaper）
const FG_DEFAULT: &str = "#E8E3D6";

pub fn render(
    scene: &str,
    out: &Path,
    cols: u16,
    rows: u16,
    color_tier: &str,
    char_tier: &str,
) -> Result<()> {
    let demo = crate::cli::parse_demo(scene)
        .ok_or_else(|| anyhow::anyhow!("未知 scene：{}", scene))?;

    // 强制色彩 / 字符档（让 Theme::detect() 走指定路径）
    std::env::set_var("MESHDROP_COLOR", color_tier);
    std::env::set_var("MESHDROP_CHARS", char_tier);

    let mut app = crate::app::App::new();
    // 让动画停在好看的相位（扫描臂 ~45° / halo 凸起）
    app.start = std::time::Instant::now() - std::time::Duration::from_millis(800);
    app.apply_demo(demo);

    let backend = TestBackend::new(cols, rows);
    let mut terminal = Terminal::new(backend)?;
    crate::app::render_once(&mut terminal, &mut app)?;

    let svg = buffer_to_svg(terminal.backend().buffer(), cols, rows);
    if let Some(parent) = out.parent() {
        if !parent.as_os_str().is_empty() {
            std::fs::create_dir_all(parent)?;
        }
    }
    std::fs::write(out, svg)?;
    Ok(())
}

fn buffer_to_svg(buf: &Buffer, cols: u16, rows: u16) -> String {
    let width = CELL_W * cols as f32;
    let height = CELL_H * rows as f32;
    let mut s = String::with_capacity(cols as usize * rows as usize * 80);

    s.push_str(&format!(
        r#"<svg xmlns="http://www.w3.org/2000/svg" width="{w:.0}" height="{h:.0}" viewBox="0 0 {w:.0} {h:.0}" font-family="{font}" font-size="{fs:.1}">"#,
        w = width,
        h = height,
        font = FONT_STACK,
        fs = FONT_SIZE,
    ));
    // 整体暗底
    s.push_str(&format!(
        r#"<rect width="{w:.0}" height="{h:.0}" fill="{bg}"/>"#,
        w = width,
        h = height,
        bg = BG_DEFAULT,
    ));

    // 第一遍：填背景色（合并相邻同色 cell 为一个 rect，减小文件大小 + 加速渲染）
    for y in 0..rows {
        let mut x = 0u16;
        while x < cols {
            let cell = buf.cell((x, y)).cloned().unwrap_or_default();
            let bg = resolve_bg(&cell);
            if bg.is_some() {
                let mut span = 1u16;
                while x + span < cols {
                    let next = buf.cell((x + span, y)).cloned().unwrap_or_default();
                    if resolve_bg(&next) == bg {
                        span += 1;
                    } else {
                        break;
                    }
                }
                s.push_str(&format!(
                    r#"<rect x="{:.1}" y="{:.1}" width="{:.1}" height="{:.1}" fill="{}"/>"#,
                    x as f32 * CELL_W,
                    y as f32 * CELL_H,
                    span as f32 * CELL_W,
                    CELL_H,
                    bg.unwrap(),
                ));
                x += span;
            } else {
                x += 1;
            }
        }
    }

    // 第二遍：字符。同色同 modifier 的相邻字符合并到一个 <text>。
    for y in 0..rows {
        let mut x = 0u16;
        while x < cols {
            let cell = buf.cell((x, y)).cloned().unwrap_or_default();
            if cell.symbol().is_empty() || cell.symbol() == " " {
                x += 1;
                continue;
            }
            let fg = resolve_fg(&cell);
            let bold = cell.modifier.contains(Modifier::BOLD);
            let dim = cell.modifier.contains(Modifier::DIM);
            let italic = cell.modifier.contains(Modifier::ITALIC);

            let mut run = String::new();
            run.push_str(cell.symbol());
            let mut span = 1u16;
            while x + span < cols {
                let next = buf.cell((x + span, y)).cloned().unwrap_or_default();
                let same = resolve_fg(&next) == fg
                    && next.modifier.contains(Modifier::BOLD) == bold
                    && next.modifier.contains(Modifier::DIM) == dim
                    && next.modifier.contains(Modifier::ITALIC) == italic
                    && !next.symbol().is_empty();
                if same {
                    let sym = next.symbol();
                    if sym == " " {
                        // 包含空格也合并到 text 里以保持列对齐
                        run.push(' ');
                    } else {
                        run.push_str(sym);
                    }
                    span += 1;
                } else {
                    break;
                }
            }
            // text 的 y 是基线：用 cell 顶 + 字号 * 0.78
            let tx = x as f32 * CELL_W;
            let ty = y as f32 * CELL_H + FONT_SIZE * 0.95;
            let weight = if bold { "700" } else { "400" };
            let opacity = if dim { 0.55 } else { 1.0 };
            let style_italic = if italic { r#" font-style="italic""# } else { "" };
            s.push_str(&format!(
                r#"<text x="{:.1}" y="{:.1}" fill="{}" font-weight="{}"{} opacity="{:.2}" xml:space="preserve">{}</text>"#,
                tx,
                ty,
                fg,
                weight,
                style_italic,
                opacity,
                escape_xml(&run),
            ));
            x += span;
        }
    }

    s.push_str("</svg>");
    s
}

fn escape_xml(s: &str) -> String {
    let mut out = String::with_capacity(s.len());
    for c in s.chars() {
        match c {
            '<' => out.push_str("&lt;"),
            '>' => out.push_str("&gt;"),
            '&' => out.push_str("&amp;"),
            '"' => out.push_str("&quot;"),
            _ => out.push(c),
        }
    }
    out
}

fn resolve_fg(cell: &Cell) -> String {
    color_to_hex(cell.fg).unwrap_or_else(|| FG_DEFAULT.to_string())
}
fn resolve_bg(cell: &Cell) -> Option<String> {
    color_to_hex(cell.bg)
}

fn color_to_hex(c: Color) -> Option<String> {
    match c {
        Color::Reset => None,
        Color::Black => Some("#000000".into()),
        Color::Red => Some("#cc0000".into()),
        Color::Green => Some("#4e9a06".into()),
        Color::Yellow => Some("#c4a000".into()),
        Color::Blue => Some("#3465a4".into()),
        Color::Magenta => Some("#75507b".into()),
        Color::Cyan => Some("#06989a".into()),
        Color::Gray => Some("#d3d7cf".into()),
        Color::DarkGray => Some("#555753".into()),
        Color::LightRed => Some("#ef2929".into()),
        Color::LightGreen => Some("#8ae234".into()),
        Color::LightYellow => Some("#fce94f".into()),
        Color::LightBlue => Some("#729fcf".into()),
        Color::LightMagenta => Some("#ad7fa8".into()),
        Color::LightCyan => Some("#34e2e2".into()),
        Color::White => Some("#eeeeec".into()),
        Color::Rgb(r, g, b) => Some(format!("#{:02x}{:02x}{:02x}", r, g, b)),
        Color::Indexed(i) => Some(indexed_to_hex(i)),
    }
}

/// 标准 256 色调色板（xterm）。
fn indexed_to_hex(i: u8) -> String {
    // 0..16: 系统色（同 ANSI）
    const SYS: [&str; 16] = [
        "#000000", "#cc0000", "#4e9a06", "#c4a000",
        "#3465a4", "#75507b", "#06989a", "#d3d7cf",
        "#555753", "#ef2929", "#8ae234", "#fce94f",
        "#729fcf", "#ad7fa8", "#34e2e2", "#eeeeec",
    ];
    if i < 16 {
        return SYS[i as usize].to_string();
    }
    if i >= 232 {
        let g = 8 + (i - 232) as u32 * 10;
        return format!("#{:02x}{:02x}{:02x}", g, g, g);
    }
    // 16..232: 6x6x6 cube
    let n = i - 16;
    let r = n / 36;
    let g = (n % 36) / 6;
    let b = n % 6;
    let step = |x: u8| -> u32 {
        if x == 0 { 0 } else { 55 + 40 * x as u32 }
    };
    format!("#{:02x}{:02x}{:02x}", step(r), step(g), step(b))
}
