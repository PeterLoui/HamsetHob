package com.hamsethob.app.ui

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.StrokeJoin
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.graphics.vector.addPathNodes
import androidx.compose.ui.unit.dp

/** أيقونات التطبيق المرسومة خصيصاً (شبكة 24×24). */
object AppIcons {

    private fun icon(name: String, strokes: List<String> = emptyList(), fills: List<String> = emptyList()) =
        ImageVector.Builder(name, 24.dp, 24.dp, 24f, 24f).apply {
            strokes.forEach {
                addPath(
                    pathData = addPathNodes(it),
                    stroke = SolidColor(Color.Black),
                    strokeLineWidth = 1.8f,
                    strokeLineCap = StrokeCap.Round,
                    strokeLineJoin = StrokeJoin.Round,
                )
            }
            fills.forEach { addPath(pathData = addPathNodes(it), fill = SolidColor(Color.Black)) }
        }.build()

    /** بيت. */
    val Home = icon(
        "Home",
        strokes = listOf("M3.5 11 12 4l8.5 7", "M5.5 9.5V20h13V9.5", "M10 20v-5h4v5"),
    )

    /** كتاب مغلق في وسطه صليب. */
    val Bible = icon(
        "Bible",
        strokes = listOf(
            "M6.5 3H18a1.5 1.5 0 0 1 1.5 1.5v15A1.5 1.5 0 0 1 18 21H6.5A2.5 2.5 0 0 1 4 18.5v-13A2.5 2.5 0 0 1 6.5 3z",
            "M7.5 3v18",
            "M13.5 7.5v9",
            "M10.5 10.5h6",
        ),
    )

    /** كتاب مفتوح (القطمارس). */
    val Readings = icon(
        "Readings",
        strokes = listOf(
            "M12 6.5C10 5 7 4.5 3 5v13c4-.5 7 0 9 1.5 2-1.5 5-2 9-1.5V5c-4-.5-7 0-9 1.5z",
            "M12 6.5v13",
            "M5.5 8.5c1.6-.1 3 .1 4 .6",
            "M5.5 11.5c1.6-.1 3 .1 4 .6",
            "M18.5 8.5c-1.6-.1-3 .1-4 .6",
            "M18.5 11.5c-1.6-.1-3 .1-4 .6",
        ),
    )

    /** نتيجة بداخلها صليب. */
    val Calendar = icon(
        "Calendar",
        strokes = listOf(
            "M5 5h14a1.5 1.5 0 0 1 1.5 1.5v12A1.5 1.5 0 0 1 19 20H5a1.5 1.5 0 0 1-1.5-1.5v-12A1.5 1.5 0 0 1 5 5z",
            "M3.5 9.5h17",
            "M8 3v4",
            "M16 3v4",
            "M12 11.5v6",
            "M9.75 13.5h4.5",
        ),
    )

    /** ثلاث نقاط. */
    val More = icon(
        "More",
        fills = listOf(
            "M6 10.3a1.7 1.7 0 1 1 0 3.4a1.7 1.7 0 1 1 0-3.4z",
            "M12 10.3a1.7 1.7 0 1 1 0 3.4a1.7 1.7 0 1 1 0-3.4z",
            "M18 10.3a1.7 1.7 0 1 1 0 3.4a1.7 1.7 0 1 1 0-3.4z",
        ),
    )

    /** ميكروفون الإذاعة. */
    val Radio = icon(
        "Radio",
        strokes = listOf(
            "M12 3a3 3 0 0 0-3 3v5a3 3 0 0 0 6 0V6a3 3 0 0 0-3-3z",
            "M6 11a6 6 0 0 0 12 0",
            "M12 17v4",
            "M9 21h6",
        ),
    )

    val Play = icon("Play", fills = listOf("M8 5.2v13.6a.8.8 0 0 0 1.2.7l10.6-6.8a.8.8 0 0 0 0-1.4L9.2 4.5A.8.8 0 0 0 8 5.2z"))
    val Pause = icon("Pause", fills = listOf("M6.5 5h3.5v14H6.5z", "M14 5h3.5v14H14z"))
    val SkipNext = icon("SkipNext", fills = listOf("M6 6.2v11.6a.7.7 0 0 0 1.1.6l8.4-5.8a.7.7 0 0 0 0-1.2L7.1 5.6A.7.7 0 0 0 6 6.2z", "M16.5 6h2v12h-2z"))

    /** رجوع ٣٠ ثانية. */
    val Back30 = icon("Back30", strokes = listOf("M12 5a7.5 7.5 0 1 1-7.5 7.5", "M12 1.8 8.8 5 12 8.2"))
    /** تقديم ٣٠ ثانية. */
    val Forward30 = icon("Forward30", strokes = listOf("M12 5a7.5 7.5 0 1 0 7.5 7.5", "M12 1.8 15.2 5 12 8.2"))

    /** خلط عشوائي (البث المتواصل). */
    val Shuffle = icon(
        "Shuffle",
        strokes = listOf("M3 7h3.5c4 0 6 10 11 10H21", "M3 17h3.5c1.6 0 2.8-1.6 3.8-3.6", "M13.7 9.6C14.7 8 15.9 7 17.5 7H21", "M18.5 4.5 21 7l-2.5 2.5", "M18.5 14.5 21 17l-2.5 2.5"),
    )
}
