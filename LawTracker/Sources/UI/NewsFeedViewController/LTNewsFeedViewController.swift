//
//  LTNewsFeedViewController.swift
//  LawTracker
//
//  Created by Varvara Mironova on 2/4/16.
//  Copyright © 2016 VarvaraMironova. All rights reserved.
//

import UIKit
let kLTMaxLoadingCount = 30

class LTNewsFeedViewController: NewsFeedViewController, UINavigationControllerDelegate, UIGestureRecognizerDelegate, LTMenuDelegate, LTFilterDelegate {
    
    var shownDate : NSDate?
    
    var dateIsChoosenFromPicker : Bool = false
    var isLoading               : Bool = false
    var loadingCount            : Int = 0
    
    var context   : LTContext?
    
    var filterType: LTType = .byCommittees {
        didSet {
            if oldValue != filterType && !isLoading {
                if let currentController = currentController as LTMainContentViewController! {
                    currentController.type = filterType
                } else if let destinationController = destinationController as LTMainContentViewController! {
                    destinationController.type = filterType
                }
            }
        }
    }
    
    var minDate : NSDate {
        get {
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            
            return dateFormatter.dateFromString("2000-01-01")!
        }
    }

    var menuViewController: LTMenuViewController {
        get {
            let menuViewController = self.storyboard!.instantiateViewControllerWithIdentifier("LTMenuViewController") as! LTMenuViewController
            menuViewController.menuDelegate = self
            
            return menuViewController
        }
    }
    
    override var rootView : LTNewsFeedRootView? {
        get {
            if isViewLoaded() && view.isKindOfClass(LTNewsFeedRootView) {
                return view as? LTNewsFeedRootView
            } else {
                return nil
            }
        }
    }
    
    //MARK: - Initializations and Deallocations
    deinit {
        //remove internet connection observing
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ReachabilityStatusChangedNotification, object: nil)
    }
    
    //MARK: - View Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupContent()
        
        //observe internet connection
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(LTNewsFeedViewController.networkStatusChanged(_:)), name: ReachabilityStatusChangedNotification, object: nil)
        Reach().monitorReachabilityChanges()
        
        if let rootView = rootView {
            let date = NSDate().previousDay()
            
            rootView.fillSearchButton(NSDate())
            
            loadData({[unowned self] (success) in
                if success {
                    self.loadChanges(date, choosenInPicker: false)
                }
            })

            //add menuViewController as a childViewController to menuContainerView
            addChildViewControllerInView(menuViewController, view: rootView.menuContainerView)
        }
    }
    
    override func viewWillTransitionToSize(size: CGSize, withTransitionCoordinator coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransitionToSize(size, withTransitionCoordinator: coordinator)
        
        coordinator.animateAlongsideTransition({[weak rootView = rootView] (UIViewControllerTransitionCoordinatorContext) -> Void in
            if rootView!.menuShown {
                rootView!.showMenu()
            }}, completion: {(UIViewControllerTransitionCoordinatorContext) -> Void in })
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(LTNewsFeedViewController.loadChangesForAnotherDate(_:)), name: "loadChangesForAnotherDate", object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "loadChangesForAnotherDate", object: nil)
    }
    
    //MARK: - Interface Handling
    @IBAction func onDismissFilterViewButton(sender: UIButton) {
        dispatch_async(dispatch_get_main_queue()) {[weak rootView = rootView] in
            rootView!.hideMenu() {finished in}
        }
    }
    
    @IBAction func onMenuButton(sender: AnyObject) {
        dispatch_async(dispatch_get_main_queue()) {[weak rootView = rootView] in
            rootView!.showMenu()
        }
    }
    
    @IBAction func onFilterButton(sender: UIButton) {
        dispatch_async(dispatch_get_main_queue()) {[unowned self, weak storyboard = storyboard, weak rootView = rootView] in
            let filterController = storyboard!.instantiateViewControllerWithIdentifier("LTFilterViewController") as! LTFilterViewController
            filterController.type = self.filterType
            filterController.filterDelegate = self
            
            if !self.isLoading {
                var entityName = String()
                switch self.filterType {
                case .byCommittees:
                    entityName = "LTCommitteeModel"
                    break
                    
                case .byInitiators:
                    entityName = "LTInitiatorModel"
                    break
                    
                case .byLaws:
                    entityName = "LTLawModel"
                    break
                }
                
                dispatch_async(CoreDataStackManager.coreDataQueue()) {[unowned self] in
                    let arrayModel = LTArrayModel(entityName: entityName, predicate: NSPredicate(value: true), date: NSDate())
                    rootView!.showLoadingViewInViewWithMessage(rootView!.contentView, message: "Завантаження фільтрів...")
                    arrayModel.filters(self.filterType, completionHandler: { (result, finish) -> Void in
                        if finish {
                            rootView!.hideLoadingView()
                            dispatch_async(dispatch_get_main_queue()) {[unowned self] in
                                filterController.filters = result
                                self.presentViewController(filterController, animated: true, completion: nil)
                            }
                        }
                    })
                }
            }
        }
    }
    
    @IBAction func onByCommitteesButton(sender: LTSwitchButton) {
        dispatch_async(dispatch_get_main_queue()) {[unowned self, weak rootView = rootView] in
            if rootView!.selectedButton != sender {
                self.scrollToTop()
                rootView!.selectedButton = sender
                self.filterType = .byCommittees
            }
        }
    }
    
    @IBAction func onByInitializersButton(sender: LTSwitchButton) {
        dispatch_async(dispatch_get_main_queue()) {[unowned self, weak rootView = rootView] in
            if rootView!.selectedButton != sender {
                self.scrollToTop()
                rootView!.selectedButton = sender
                self.filterType = .byInitiators
            }
        }
    }
    
    @IBAction func byLawsButton(sender: LTSwitchButton) {
        dispatch_async(dispatch_get_main_queue()) {[unowned self, weak rootView = rootView] in
            self.scrollToTop()
            if rootView!.selectedButton != sender {
                self.scrollToTop()
                rootView!.selectedButton = sender
                self.filterType = .byLaws
            }
        }
    }
    
    @IBAction func onSearchButton(sender: AnyObject) {
        dispatch_async(dispatch_get_main_queue()) {[weak rootView = rootView] in
            rootView!.showDatePicker()
        }
    }
    
    @IBAction func onHidePickerButton(sender: AnyObject) {
        dispatch_async(dispatch_get_main_queue()) {[weak rootView = rootView] in
            rootView!.hideDatePicker()
        }
    }
    
    @IBAction func onDonePickerButton(sender: AnyObject) {
        let client = LTClient.sharedInstance()
        if let task = client.downloadTask as NSURLSessionDataTask! {
            task.cancel()
        }
        
        isLoading = false
        
        dispatch_async(dispatch_get_main_queue()) {[unowned self, weak rootView = rootView] in
            if let rootView = rootView {
                rootView.hideDatePicker()
                
                if self.isLoading {
                    return
                }
                
                self.scrollToTop()
                let date = self.dateInPicker()
                
                self.loadChanges(date, choosenInPicker: true)
            }
        }
    }
    
    func refreshData() {
        dispatch_async(dispatch_get_main_queue()) {[unowned self, weak date = dateInPicker()] in
            let alertViewController: UIAlertController = UIAlertController(title: "Оновити базу законопроектів, ініціаторів та комітетів?", message:"Це може зайняти кілька хвилин", preferredStyle: .Alert)
            alertViewController.addAction(UIAlertAction(title: "Так", style: .Default, handler: { (UIAlertAction) in
                self.loadData({ (success) in
                    if success {
                        self.loadChanges(date!, choosenInPicker: false)
                    }
                })
            }))
            
            alertViewController.addAction(UIAlertAction(title: "Ні", style: .Default, handler: nil))
    
            self.presentViewController(alertViewController, animated: true, completion: nil)
        }
    }
    
    // MARK: - UIGestureRecognizerDelegate
    override func gestureRecognizerShouldBegin(gestureRecognizer: UIGestureRecognizer) -> Bool {
        if isLoading {
            return false
        }
        
        let shouldBegin = super.gestureRecognizerShouldBegin(gestureRecognizer)
        let tableView = currentController!.rootView!.contentTableView
        let bounds = tableView.bounds
        let date = dateInPicker().dateWithoutTime()
        if !shouldBegin &&
            (CGRectGetMinY(bounds) <= 0 &&
                .Down == navigationGesture.direction &&
                date.compare(NSDate().dateWithoutTime()) == .OrderedSame)
        {
            refreshData()
        }
        
        if (.Up == navigationGesture.direction && date.compare(minDate) == .OrderedSame) {
            return false
        }
        
        return shouldBegin
    }
    
    // MARK: - Private
    private func loadData(completionHandler:(success: Bool) -> Void) {
        let settingsModel = VTSettingModel()
        let context = LTContext()
        let firstLaunch = settingsModel.firstLaunch
        let message = firstLaunch != true ? "Зачекайте, будь ласка.\nТриває завантаження законопроектів, комітетів та ініціаторів..." : "Зачекайте, будь ласка.\nТриває оновлення даних"
        
        context.checkConnection {[unowned self, weak rootView = rootView] (isConnection, error) in
            if isConnection {
                //download data
                self.isLoading = true
                if let rootView = rootView {
                    rootView.showLoadingViewInViewWithMessage(rootView.contentView, message: message)
                    context.loadData(firstLaunch) { (success, error) in
                        self.isLoading = false
                        rootView.hideLoadingView()
                        
                        if success {
                            settingsModel.firstLaunch = true
                            rootView.setFilterImages()
                        } else {
                            if let error = error {
                                self.processError(error){[unowned self] void in
                                    self.loadData(){ (success) in
                                        
                                    }
                                }
                            }
                        }
                        
                        completionHandler(success: success)
                    }
                }
            } else {
                if firstLaunch {
                    let date = NSDate().previousDay()
                    self.loadChanges(date, choosenInPicker: false)
                } else {
                    if let error = error {
                        self.processError(error){[unowned self] void in
                            self.loadData(){ (success) in
                                
                            }
                        }
                    }
                }
            }
        }
        
    }
    
    private func loadChanges(date: NSDate, choosenInPicker: Bool) {
        if let rootView = rootView {
            dateIsChoosenFromPicker = choosenInPicker
            rootView.fillSearchButton(date)
            let context = LTContext()
            self.isLoading = true
            
            rootView.showLoadingViewInViewWithMessage(rootView.contentView, message: "Завантажую новини за \(date.longString()) \nЗалишилося кілька секунд...")
            
            context.loadChanges(date, choosenInPicker: choosenInPicker, completionHandler: {[unowned self] (success, error) in
                self.isLoading = false
                rootView.hideLoadingView()
                
                if success {
                    self.setCurrentControllerWithDate(date)
                } else {
                    if let error = error {
                        self.processError(error){void in
                            context.loadChanges(date, choosenInPicker: choosenInPicker, completionHandler: { (success, error) in
                            })
                        }
                    }
                }
            })
        }
    }
    
    private func setupContent() {
        if let rootView = rootView as LTNewsFeedRootView! {
            currentController = storyboard!.instantiateViewControllerWithIdentifier("LTMainContentViewController") as? LTMainContentViewController
            let containerView = rootView.contentView
            addChildViewControllerInView(currentController!, view: containerView)
            
            setCurrentController(currentController!, animated: false, forwardDirection: false)
            scrollToTop()
        }
    }
    
    private func setCurrentControllerWithDate(date: NSDate) {
        if let destinationController = destinationController as LTMainContentViewController! {
            destinationController.type = filterType
            destinationController.loadingDate = date
        } else {
            currentController!.type = filterType
            currentController!.loadingDate = date
        }
    }
    
    private func processError(error:NSError, completionHandler:(UIAlertAction) -> Void) {
        rootView!.hideLoadingView()
        isLoading = false
        var title = String()

        switch error.code {
        case -998:
            title = "Щось негаразд."
            break
            
        case -999:
            title = "Скасовано."
            break
            
        case -1000:
            title = "Не вдалося згенерувати URL."
            break
            
        case -1001:
            title = "Перевищено час очікування відповіді серверу."
            break
            
        case -1003, -1004:
            title = "Не вдалось зв’язатися з сервером."
            break
            
        case -1005:
            title = "Інтернет-зв’язок перервався."
            break
            
        case -1009:
            title = "Немає доступу до Інтернету."
            break
            
        case -1011:
            title = "Некоректна відповідь сервера."
            break
            
        case -1015, -1016:
            title = "Не вдалося декодувати дані."
            break
            
        case -1017:
            title = "Некоректна структура відповіді сервера."
            break
            
        case 3840:
            title = "Некоректний формат даних."
            break
            
        default:
            title = error.localizedDescription
            break
        }
        
        dispatch_async(dispatch_get_main_queue()) {[unowned self] in
            let alertViewController: UIAlertController = UIAlertController(title: title, message: "Повторити спробу завантаження?", preferredStyle: .Alert)
            alertViewController.addAction(UIAlertAction(title: "Так", style: .Default, handler: completionHandler))
            
            alertViewController.addAction(UIAlertAction(title: "Ні", style: .Default, handler: nil))
            
            self.presentViewController(alertViewController, animated: true, completion: nil)
        }
    }
    
    //MARK: - LTMenuDelegate methods
    func hideMenu(completionHandler: (finished: Bool) -> Void) {
        if let rootView = rootView {
            rootView.hideMenu({ (finished) -> Void in
                completionHandler(finished: finished)
            })
            
            return
        }
        
        completionHandler(finished: false)
    }
    
    //MARK: - LTFilterDelegate methods
    func filtersDidApplied() {
       if isLoading {
            return
        }
        
        rootView!.setFilterImages()
        if let currentController = currentController as LTMainContentViewController! {
            currentController.arrayModelFromChanges()
        }
    }
    
    //MARK: - NewsFeedController methods
    override func downloadContent(forPreviousDay: Bool) {
        super.downloadContent(forPreviousDay)
        
        let dip = dateInPicker()
        let date = forPreviousDay ? dip.previousDay() : dip.nextDay()
        
        loadChanges(date, choosenInPicker: false)
    }
    
    override func scrollToTop() {
        super.scrollToTop()
        if let currentController = currentController as LTMainContentViewController! {
            if let currentControllerView = currentController.rootView as LTMainContentRootView! {
                currentControllerView.contentTableView.setContentOffset(CGPointZero, animated: false)
            }
        } else if let destinationController = destinationController as LTMainContentViewController! {
            if let destinationControllerView = destinationController.rootView as LTMainContentRootView! {
                destinationControllerView.contentTableView.setContentOffset(CGPointZero, animated: false)
            }
        }
    }
    
    override func dateInPicker() -> NSDate {
        return rootView!.datePicker.date
    }
    
    //MARK: - NSNotificationCenter
    func networkStatusChanged(notification: NSNotification) {
        let userInfo = notification.userInfo
        print(userInfo)
    }
    
    func loadChangesForAnotherDate(notification: NSNotification) {
        isLoading = false
        if nil == rootView {
            return
        }
    
        let date = nil == shownDate ? NSDate().previousDay() : shownDate
        if let userInfo = notification.userInfo as NSDictionary! {
            let dip = dateInPicker()
            
            if let needLoadChangesForAnotherDate = userInfo["needLoadChangesForAnotherDay"] as? Bool {
                if needLoadChangesForAnotherDate {
                    if !dateIsChoosenFromPicker && (dip.compare(NSDate().dateWithoutTime()) != .OrderedSame) && (loadingCount < kLTMaxLoadingCount) && dip.compare(minDate) != .OrderedSame {
                        loadingCount += 1
                        var newDate = date
                        if date!.dateWithoutTime().compare(dip.dateWithoutTime()) == .OrderedAscending {
                            newDate = dip.nextDay()
                        } else {
                            newDate = dip.previousDay()
                        }
                        
                        self.loadChanges(newDate!, choosenInPicker: false)
                        
                        return
                    }
                    
                    if loadingCount == kLTMaxLoadingCount {
                        if let currentController = currentController as LTMainContentViewController! {
                            currentController.rootView!.noSubscriptionsLabel.text = "За встановленими фільтрами немає змін протягом останніх \(kLTMaxLoadingCount) днів"
                        }
                    }
                    
                }
                
                shownDate = dip
                loadingCount = 0
            }
        }
    }
    
}
