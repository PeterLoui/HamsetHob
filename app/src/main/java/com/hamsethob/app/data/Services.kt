package com.hamsethob.app.data

import android.content.Context
import com.hamsethob.app.bible.BibleRepository
import com.hamsethob.app.bible.Favorites
import com.hamsethob.app.calendar.SaintImageRepository

/** المستودعات المشتركة بين الشاشات. */
class Services(context: Context) {
    val app: Context = context.applicationContext
    val bible = BibleRepository(app)
    val images = SaintImageRepository(app)
    val katameros = KatamerosRepository(app)
    val favorites = Favorites.get(app)
    val settings = AppSettings.get(app)
}
