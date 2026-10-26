package com.hamsethob.app.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.blur
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.draw.drawWithContent
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.CompositingStrategy
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Shape
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/** يجعل الحافة السفلية للمحتوى تتلاشى تدريجياً بدل أن تُقطع فجأة. */
fun Modifier.fadeBottomEdge(height: Dp): Modifier = this
    .graphicsLayer { compositingStrategy = CompositingStrategy.Offscreen }
    .drawWithContent {
        drawContent()
        val fade = height.toPx().coerceAtMost(size.height)
        drawRect(
            Brush.verticalGradient(
                0f to Color.Black,
                ((size.height - fade) / size.height) to Color.Black,
                1f to Color.Transparent,
            ),
            blendMode = BlendMode.DstIn,
        )
    }

/** خلفية متدرجة بفقاعات لونية ناعمة تشبه خلفيات Magic OS، تتلون بالموسم الكنسي. */
@Composable
fun Wallpaper(modifier: Modifier = Modifier) {
    val colors = LocalAppColors.current
    Box(modifier.fillMaxSize().background(Brush.verticalGradient(colors.wallpaper))) {
        Canvas(Modifier.fillMaxSize().blur(60.dp)) {
            val spots = listOf(
                Triple(0.85f, 0.12f, 0.55f), Triple(0.10f, 0.30f, 0.60f),
                Triple(0.70f, 0.62f, 0.50f), Triple(0.20f, 0.90f, 0.65f),
            )
            spots.forEachIndexed { i, (x, y, r) ->
                val center = Offset(size.width * x, size.height * y)
                drawCircle(
                    Brush.radialGradient(listOf(colors.blobs[i], Color.Transparent), center, size.width * r),
                    radius = size.width * r,
                    center = center,
                )
            }
        }
    }
}

/**
 * سطح "زجاج سائل": طبقة خلفية (صورة مثلاً) + غشاء زجاجي متدرج + لمعة
 * سطحية + حافة مضيئة متدرجة، على غرار واجهة Magic OS 11.
 */
@Composable
fun LiquidGlass(
    modifier: Modifier = Modifier,
    shape: Shape = RoundedCornerShape(32.dp),
    elevation: Dp = 22.dp,
    backdrop: @Composable BoxScope.() -> Unit = {},
    content: @Composable BoxScope.() -> Unit,
) {
    val colors = LocalAppColors.current
    val shadow = if (colors.isDark) Color(0x99200A30) else Color(0x40806090)
    Box(
        modifier
            .shadow(elevation, shape, ambientColor = shadow, spotColor = shadow)
            .clip(shape)
            .background(colors.glassTint)
    ) {
        backdrop()
        // غشاء الزجاج واللمعة والانعكاس السفلي
        Box(
            Modifier
                .matchParentSize()
                .drawWithCache {
                    val film = Brush.verticalGradient(colors.glassFilm)
                    val sheen = Brush.radialGradient(
                        listOf(Color(0x55FFFFFF), Color.Transparent),
                        center = Offset(size.width * 0.15f, 0f),
                        radius = size.width * 0.75f,
                    )
                    val caustic = Brush.radialGradient(
                        listOf(Color(0x22FFD9EC), Color.Transparent),
                        center = Offset(size.width * 0.9f, size.height),
                        radius = size.width * 0.5f,
                    )
                    onDrawBehind {
                        drawRect(film)
                        drawRect(sheen)
                        drawRect(caustic)
                    }
                }
                .border(1.2.dp, Brush.linearGradient(colors.glassRim), shape)
        )
        content()
    }
}
