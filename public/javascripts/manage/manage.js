var manageApp = angular.module ( 'manage', [] )

manageApp.config ( ['$routeProvider', function ( $routeProvider ) {
  $routeProvider.
    when ( '/home', { templateUrl: '/templates/manage/index.html', controller: 'ManageDashboardController' } ).
    when ( '/authorize', { templateUrl: '/templates/manage/sessions/new.html', controller: 'ManageSessionController' } ).
    when ( '/sales', { templateUrl: '/templates/manage/sales/index.html', controller: 'ManageSalesController' } ).
    when ( '/sales/new', { templateUrl: '/templates/manage/sales/new.html', controller: 'ManageSalesController' } ).
    when ( '/sales/:id', { templateUrl: '/templates/manage/sales/show.html', controller: 'ManageSalesController' } ).
    otherwise ( { redirectTo: '/home' } );
}]);
