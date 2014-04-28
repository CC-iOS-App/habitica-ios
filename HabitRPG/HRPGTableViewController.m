//
//  HRPGTableViewController.m
//  HabitRPG
//
//  Created by Phillip Thelen on 08/03/14.
//  Copyright (c) 2014 Phillip Thelen. All rights reserved.
//

#import "HRPGTableViewController.h"
#import "HRPGAppDelegate.h"
#import "HRPGFormViewController.h"
#import "Task.h"
#import <PDKeychainBindings.h>
#import "MCSwipeTableViewCell.h"
#import "HRPGSwipeTableViewCell.h"

@interface HRPGTableViewController ()
@property NSString *readableName;
@property NSString *typeName;
@property HRPGManager *sharedManager;
@property NSIndexPath *openedIndexPath;
@property int indexOffset;

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath withAnimation:(BOOL) animate;
@end

@implementation HRPGTableViewController
@synthesize managedObjectContext;
Task *editedTask;
BOOL editable;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    editable = NO;

    HRPGAppDelegate *appdelegate = (HRPGAppDelegate*)[[UIApplication sharedApplication] delegate];
    _sharedManager = appdelegate.sharedManager;
    self.managedObjectContext = _sharedManager.getManagedObjectContext;
    
    UIRefreshControl *refresh = [[UIRefreshControl alloc] init];
    [refresh addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    self.refreshControl = refresh;
    
    PDKeychainBindings *keyChain = [PDKeychainBindings sharedKeychainBindings];

    if ([keyChain stringForKey:@"id"] == nil) {
        UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
        UINavigationController *navigationController = (UINavigationController *)[storyboard instantiateViewControllerWithIdentifier:@"loginNavigationController"];
        [self presentViewController:navigationController animated:NO completion: nil];
    }
}

-(void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.refreshControl.isRefreshing) {
        dispatch_async(dispatch_get_main_queue(), ^
        {
            [self.refreshControl beginRefreshing];
            [self.refreshControl endRefreshing];
        });
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void) refresh {
    [_sharedManager fetchUser:^ () {
        [self.refreshControl endRefreshing];
    } onError:^ () {
        [self.refreshControl endRefreshing];
        [_sharedManager displayNetworkError];
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return [[self.fetchedResultsController sections] count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    id <NSFetchedResultsSectionInfo> sectionInfo = [self.fetchedResultsController sections][section];
    return [sectionInfo numberOfObjects] + self.indexOffset;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    HRPGSwipeTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"Cell" forIndexPath:indexPath];
    [cell setDefaultColor:[UIColor lightGrayColor]];
    [self configureCell:cell atIndexPath:indexPath withAnimation:NO];
    return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    return editable;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        
        if (editingStyle == UITableViewCellEditingStyleDelete) {
            Task *task = [self.fetchedResultsController objectAtIndexPath:indexPath];
            [_sharedManager deleteTask:task onSuccess:^() {
            }onError:^() {
                
            }];
        }
    }
}

- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // The table view should not be re-orderable.
    return editable;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    [self.tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    // fix for separators bug in iOS 7
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
    
    if (tableView.editing ) {
        editedTask = [self.fetchedResultsController objectAtIndexPath:indexPath];
        [self performSegueWithIdentifier: @"FormSegue" sender: self];
        return;
    }
    
    if (self.openedIndexPath.item+self.indexOffset < indexPath.item && self.indexOffset > 0) {
        indexPath = [NSIndexPath indexPathForItem:indexPath.item - self.indexOffset inSection:indexPath.section];
    }
    Task *task = [self.fetchedResultsController objectAtIndexPath:indexPath];
    NSNumber *checklistCount = [NSNumber numberWithInteger:[task.checklist count]];
    if (self.openedIndexPath != nil && self.openedIndexPath.item == indexPath.item) {
        NSIndexPath *tempPath = self.openedIndexPath;
        self.openedIndexPath = nil;
        self.indexOffset = 0;
        [self configureCell:[tableView cellForRowAtIndexPath:tempPath] atIndexPath:tempPath withAnimation:YES];
        NSMutableArray *deleteArray = [[NSMutableArray alloc] init];
        for(int i=1; i<=[checklistCount integerValue]; i++) {
            [deleteArray addObject:[NSIndexPath indexPathForItem:indexPath.item+i inSection:self.openedIndexPath.section]];
        }
        [self.tableView deleteRowsAtIndexPaths:deleteArray withRowAnimation:UITableViewRowAnimationTop];
    } else {
        if (self.openedIndexPath){
            Task *oldTask = [self.fetchedResultsController objectAtIndexPath:self.openedIndexPath];
            NSNumber *oldChecklistCount = [oldTask valueForKeyPath:@"checklist.@count"];
            
            NSMutableArray *deleteArray = [[NSMutableArray alloc] init];
            for(int i=1; i<=[oldChecklistCount integerValue]; i++) {
                [deleteArray addObject:[NSIndexPath indexPathForItem:self.openedIndexPath.item+i inSection:self.openedIndexPath.section]];
            }
            NSIndexPath *tempPath = self.openedIndexPath;
            self.openedIndexPath = nil;
            self.indexOffset = 0;
            [self configureCell:[tableView cellForRowAtIndexPath:tempPath] atIndexPath:tempPath withAnimation:YES];
            [self.tableView deleteRowsAtIndexPaths:deleteArray withRowAnimation:UITableViewRowAnimationBottom];
        }
        if ([checklistCount integerValue] > 0) {
            self.openedIndexPath = indexPath;
            self.indexOffset = (int)[checklistCount integerValue];
            NSMutableArray *insertArray = [[NSMutableArray alloc] init];
            for(int i=1; i<=[checklistCount integerValue]; i++) {
                [insertArray addObject:[NSIndexPath indexPathForItem:self.openedIndexPath.item+i inSection:self.openedIndexPath.section]];
            }
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath withAnimation:YES];
            [self.tableView insertRowsAtIndexPaths:insertArray withRowAnimation:UITableViewRowAnimationTop];
        }
    }
}


- (IBAction)editButtonSelected:(id)sender {
    if ([self isEditing]) {
        editable = NO;
        [self setEditing:NO animated:YES];
    } else {
        editable = YES;
        [self setEditing:YES animated:YES];
    }
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animated {
    [super setEditing:editing animated:animated];
    if (editing) {
        editable = YES;
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(editButtonSelected:)];
    } else {
        editable = NO;
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit target:self action:@selector(editButtonSelected:)];
    }
}

- (IBAction)unwindToList:(UIStoryboardSegue *)segue
{
    
}


- (IBAction)unwindToListSave:(UIStoryboardSegue *)segue
{
    HRPGFormViewController *formViewController = (HRPGFormViewController*)segue.sourceViewController;
    if (formViewController.editTask) {
        [_sharedManager updateTask:formViewController.task onSuccess:^() {
            
        }onError:^() {
            
        }];
    } else {
        [_sharedManager createTask:formViewController.task onSuccess:^() {
    
        }onError:^() {
        
        }];
    }
}


- (NSFetchedResultsController *)fetchedResultsController
{
    if (_fetchedResultsController != nil) {
        return _fetchedResultsController;
    }
    
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    // Edit the entity name as appropriate.
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Task" inManagedObjectContext:self.managedObjectContext];
    [fetchRequest setEntity:entity];
    
    // Set the batch size to a suitable number.
    [fetchRequest setFetchBatchSize:20];
    NSPredicate *predicate;
    if ([_typeName  isEqual:@"todo"]) {
        predicate = [NSPredicate predicateWithFormat:@"type=='todo' && completed==NO"];
    } else {
        predicate = [NSPredicate predicateWithFormat:@"type==%@", _typeName];
    }
    [fetchRequest setPredicate:predicate];
    
    // Edit the sort key as appropriate.
    NSSortDescriptor *sortDescriptor = [[NSSortDescriptor alloc] initWithKey:@"id" ascending:NO];
    NSArray *sortDescriptors = @[sortDescriptor];
    
    [fetchRequest setSortDescriptors:sortDescriptors];
    
    // Edit the section name key path and cache name if appropriate.
    // nil for section name key path means "no sections".
    NSFetchedResultsController *aFetchedResultsController = [[NSFetchedResultsController alloc] initWithFetchRequest:fetchRequest managedObjectContext:self.managedObjectContext sectionNameKeyPath:nil cacheName:_typeName];
    aFetchedResultsController.delegate = self;
    self.fetchedResultsController = aFetchedResultsController;
    
	NSError *error = nil;
	if (![self.fetchedResultsController performFetch:&error]) {
        // Replace this implementation with code to handle the error appropriately.
        // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
	    NSLog(@"Unresolved error %@, %@", error, [error userInfo]);
	    abort();
	}
    
    return _fetchedResultsController;
}


- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
           atIndex:(NSUInteger)sectionIndex forChangeType:(NSFetchedResultsChangeType)type
{
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [self.tableView insertSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [self.tableView deleteSections:[NSIndexSet indexSetWithIndex:sectionIndex] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject
       atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type
      newIndexPath:(NSIndexPath *)newIndexPath
{
    UITableView *tableView = self.tableView;
    
    switch(type) {
        case NSFetchedResultsChangeInsert:
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeDelete:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
            
        case NSFetchedResultsChangeUpdate:
            [self configureCell:[tableView cellForRowAtIndexPath:indexPath] atIndexPath:indexPath withAnimation:YES];
            break;
            
        case NSFetchedResultsChangeMove:
            [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
            [tableView insertRowsAtIndexPaths:@[newIndexPath] withRowAnimation:UITableViewRowAnimationFade];
            break;
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    [self.tableView endUpdates];
}

- (void)configureCell:(UITableViewCell *)cell atIndexPath:(NSIndexPath *)indexPath withAnimation:(BOOL)animate
{
    NSManagedObject *object = [self.fetchedResultsController objectAtIndexPath:indexPath];
    cell.textLabel.text = [[object valueForKey:@"text"] description];
}

-(void)configureSwiping:(HRPGSwipeTableViewCell *)cell withTask:(Task*) task {
}


#pragma mark - Navigation

// In a story board-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier isEqualToString:@"FormSegue"]) {
        UINavigationController *destViewController = segue.destinationViewController;
        
        HRPGFormViewController *formController = (HRPGFormViewController*)destViewController.topViewController;
        formController.taskType = self.typeName;
        if (editedTask) {
            formController.editTask = YES;
            formController.task = editedTask;
            editedTask = nil;
            destViewController.topViewController.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"Edit %@", nil), self.readableName];
        } else {
            destViewController.topViewController.navigationItem.title = [NSString stringWithFormat:NSLocalizedString(@"Add %@", nil), self.readableName];
        }
    }
}

@end
