package com.niki.xxread

import android.os.Bundle
import android.util.Log
import android.view.View
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import java.io.File
import kotlinx.coroutines.launch
import org.readium.adapter.pdfium.document.PdfiumDocumentFactory
import org.readium.r2.navigator.epub.EpubNavigatorFactory
import org.readium.r2.navigator.epub.EpubNavigatorFragment
import org.readium.r2.shared.publication.Publication
import org.readium.r2.shared.publication.services.isRestricted
import org.readium.r2.shared.util.asset.AssetRetriever
import org.readium.r2.shared.util.getOrElse
import org.readium.r2.shared.util.http.DefaultHttpClient
import org.readium.r2.shared.util.toUrl
import org.readium.r2.streamer.PublicationOpener
import org.readium.r2.streamer.parser.DefaultPublicationParser

class ReadiumEpubActivity : AppCompatActivity() {
    private val httpClient by lazy { DefaultHttpClient() }
    private val assetRetriever by lazy { AssetRetriever(contentResolver, httpClient) }
    private val publicationOpener by lazy {
        PublicationOpener(
            publicationParser = DefaultPublicationParser(
                this,
                assetRetriever = assetRetriever,
                httpClient = httpClient,
                pdfFactory = PdfiumDocumentFactory(this),
            ),
            contentProtections = emptyList(),
        )
    }

    private var publication: Publication? = null

    private lateinit var loadingView: View
    private lateinit var containerView: View

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContentView(R.layout.activity_readium_epub)

        loadingView = findViewById(R.id.readium_loading)
        containerView = findViewById(R.id.readium_container)

        if (savedInstanceState != null) {
            showNavigatorView()
            return
        }

        val filePath = intent.getStringExtra(EXTRA_FILE_PATH)
        if (filePath.isNullOrBlank()) {
            finishWithError("missing_file_path")
            return
        }

        openPublication(filePath)
    }

    private fun openPublication(filePath: String) {
        lifecycleScope.launch {
            try {
                val file = File(filePath)
                if (!file.exists()) {
                    finishWithError("file_not_found: $filePath")
                    return@launch
                }

                val asset = assetRetriever.retrieve(file.toUrl()).getOrElse { error ->
                    throw IllegalStateException("retrieve_failed: $error")
                }
                val openedPublication =
                    publicationOpener.open(asset, allowUserInteraction = false).getOrElse { error ->
                        throw IllegalStateException("open_failed: $error")
                    }

                if (openedPublication.isRestricted) {
                    openedPublication.close()
                    finishWithError("publication_restricted")
                    return@launch
                }

                if (!openedPublication.conformsTo(Publication.Profile.EPUB)) {
                    openedPublication.close()
                    finishWithError("not_epub_profile")
                    return@launch
                }

                publication = openedPublication
                showNavigator(openedPublication)
            } catch (error: Throwable) {
                finishWithError("open_exception: ${error.message}")
            }
        }
    }

    private fun showNavigator(publication: Publication) {
        val navigatorFactory = EpubNavigatorFactory(publication)
        supportFragmentManager.fragmentFactory = navigatorFactory.createFragmentFactory(
            initialLocator = null,
        )

        supportFragmentManager.beginTransaction()
            .replace(
                R.id.readium_container,
                EpubNavigatorFragment::class.java,
                Bundle(),
                TAG_NAVIGATOR,
            )
            .commitNow()

        showNavigatorView()
    }

    private fun showNavigatorView() {
        loadingView.visibility = View.GONE
        containerView.visibility = View.VISIBLE
    }

    private fun finishWithError(reason: String) {
        Log.w(TAG, "Readium open failed: $reason")
        Toast.makeText(this, "Readium 打开失败，已回退到当前阅读器", Toast.LENGTH_SHORT).show()
        finish()
    }

    override fun onDestroy() {
        publication?.close()
        publication = null
        super.onDestroy()
    }

    companion object {
        const val EXTRA_FILE_PATH = "filePath"
        private const val TAG = "ReadiumEpubActivity"
        private const val TAG_NAVIGATOR = "readium_epub_navigator"
    }
}
