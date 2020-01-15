
import Foundation

public final class ArticleCacheController: CacheController {
    
    override public func add(url: URL, groupKey: CacheController.GroupKey, itemKey: CacheController.ItemKey? = nil, bypassGroupDeduping: Bool = false, itemCompletion: @escaping CacheController.ItemCompletionBlock, groupCompletion: @escaping CacheController.GroupCompletionBlock) {
        super.add(url: url, groupKey: groupKey, itemKey: itemKey, bypassGroupDeduping: bypassGroupDeduping, itemCompletion: itemCompletion, groupCompletion: groupCompletion)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.dbWriter.fetchAndPrintEachItem()
            self.dbWriter.fetchAndPrintEachGroup()
        }
    }
    
    public override func remove(groupKey: CacheController.GroupKey, itemCompletion: @escaping CacheController.ItemCompletionBlock, groupCompletion: @escaping CacheController.GroupCompletionBlock) {
        super.remove(groupKey: groupKey, itemCompletion: itemCompletion, groupCompletion: groupCompletion)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            self.dbWriter.fetchAndPrintEachItem()
            self.dbWriter.fetchAndPrintEachGroup()
        }
    }

    public func cacheFromMigration(desktopArticleURL: URL, itemKey: String? = nil, content: String, mimeType: String) { //articleURL should be desktopURL
        
        guard let articleDBWriter = dbWriter as? ArticleCacheDBWriter,
        let articleFileWriter = fileWriter as? ArticleCacheFileWriter else {
            return
        }
        
        articleDBWriter.cacheMobileHtmlFromMigration(desktopArticleURL: desktopArticleURL, success: { itemKey in
            
            articleFileWriter.migrateCachedContent(content: content, itemKey: itemKey, mimeType: mimeType, success: {
                
                articleDBWriter.migratedCacheItemFile(itemKey: itemKey, success: {
                    print("successfully migrated")
                    
                    DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 10) {
                        self.dbWriter.fetchAndPrintEachItem()
                        self.dbWriter.fetchAndPrintEachGroup()
                    }
                    
                }) { (error) in
                    //tonitodo: broadcast migration error
                }
            }) { (error) in
                //tonitodo: broadcast migration error
            }
        }) { (error) in
            //tonitodo: broadcast migration error
        }
    }
}