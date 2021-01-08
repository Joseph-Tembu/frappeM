import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_pagewise/flutter_pagewise.dart';
import 'package:frappe_app/widgets/header_app_bar.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;

import '../datamodels/doctype_response.dart';

import '../app.dart';
import '../app/locator.dart';
import '../app/router.gr.dart';

import '../views/filter_list.dart';

import '../services/api/api.dart';
import '../services/navigation_service.dart';

import '../config/palette.dart';
import '../config/frappe_icons.dart';

import '../utils/cache_helper.dart';
import '../utils/helpers.dart';
import '../utils/config_helper.dart';
import '../utils/frappe_icon.dart';
import '../utils/enums.dart';

import '../widgets/frappe_button.dart';
import '../widgets/list_item.dart';
import 'no_internet.dart';

class CustomListView extends StatefulWidget {
  final String doctype;

  final Function filterCallback;

  CustomListView({
    @required this.doctype,
    this.filterCallback,
  });

  @override
  _CustomListViewState createState() => _CustomListViewState();
}

class _CustomListViewState extends State<CustomListView> {
  static const int PAGE_SIZE = 10;
  final userId = ConfigHelper().userId;
  var _pageLoadController;
  bool showLiked;

  @override
  void dispose() {
    super.dispose();
    _pageLoadController?.dispose();
  }

  _getData() async {
    var meta = await CacheHelper.getMeta(widget.doctype);
    var isOnline = await verifyOnline();
    var cachedFilter = CacheHelper.getCache('${widget.doctype}Filter');
    List filter = cachedFilter["data"] ?? [];

    // if (filter.isEmpty) {
    //   if (ConfigHelper().userId != null) {
    //     filter.add(
    //       [widget.doctype, "_assign", "like", "%${ConfigHelper().userId}%"],
    //     );
    //   }
    // }

    _pageLoadController = PagewiseLoadController(
      pageSize: PAGE_SIZE,
      pageFuture: (pageIndex) {
        return locator<Api>().fetchList(
          meta: meta.docs[0],
          doctype: widget.doctype,
          fieldnames: generateFieldnames(
            widget.doctype,
            meta.docs[0],
          ),
          pageLength: PAGE_SIZE,
          filters: filter,
          offset: pageIndex * PAGE_SIZE,
        );
      },
    );

    return {
      "meta": meta,
      "isOnline": isOnline,
      "filter": filter,
    };
  }

  Widget _generateItem({
    Map data,
    Function onListTap,
    Function onButtonTap,
    DoctypeDoc meta,
  }) {
    var assignee =
        data["_assign"] != null ? json.decode(data["_assign"]) : null;

    var likedBy =
        data["_liked_by"] != null ? json.decode(data["_liked_by"]) : [];
    var isLikedByUser = likedBy.contains(userId);

    var seenBy = data["_seen"] != null ? json.decode(data["_seen"]) : [];
    var isSeenByUser = seenBy.contains(userId);

    return ListItem(
      doctype: widget.doctype,
      onListTap: onListTap,
      isFav: isLikedByUser,
      seen: isSeenByUser,
      assignee: assignee != null && assignee.length > 0
          ? ['_assign', assignee[0]]
          : null,
      onButtonTap: onButtonTap,
      title: getTitle(meta, data),
      modifiedOn: "${timeago.format(
        DateTime.parse(
          data['modified'],
        ),
      )}",
      name: data["name"],
      status: ["status", data["status"]],
      commentCount: data["_comment_count"],
    );
  }

  Widget _noItemsFoundBuilder(List filters) {
    return Container(
      color: Colors.white,
      width: MediaQuery.of(context).size.width,
      height: MediaQuery.of(context).size.height - 100,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Text('No Items Found'),
          if (filters.isNotEmpty)
            FrappeFlatButton.small(
              buttonType: ButtonType.secondary,
              title: 'Clear Filters',
              onPressed: () {
                FilterList.clearFilters(widget.doctype);
                filters.clear();
                _pageLoadController.reset();
                setState(() {});
              },
            ),
          FrappeFlatButton.small(
            buttonType: ButtonType.primary,
            title: 'Create New',
            onPressed: () {
              locator<NavigationService>().navigateTo(
                Routes.newDoc,
                arguments: NewDocArguments(
                  doctype: widget.doctype,
                ),
              );
            },
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: _getData(),
      builder: (context, snapshot) {
        if (snapshot.hasData &&
            snapshot.connectionState == ConnectionState.done) {
          var meta = snapshot.data["meta"];
          var filters = snapshot.data["filter"];
          var isOnline = snapshot.data["isOnline"];

          if (FilterList.getFieldFilterIndex(filters, '_liked_by') != null) {
            showLiked = true;
          } else {
            showLiked = false;
          }

          return Scaffold(
            bottomNavigationBar: Container(
              height: 60,
              child: BottomAppBar(
                color: Colors.white,
                child: Row(
                  children: <Widget>[
                    Spacer(),
                    FrappeRaisedButton(
                      minWidth: 120,
                      onPressed: () async {
                        var saved = await showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          builder: (BuildContext context) {
                            return FractionallySizedBox(
                              heightFactor: 0.96,
                              child: FilterList(
                                doctype: widget.doctype,
                              ),
                            );
                          },
                        );

                        if (saved) {
                          setState(() {});
                        }
                      },
                      title: 'Filters (${filters.length})',
                      icon: FrappeIcons.filter,
                    ),
                    SizedBox(
                      width: 10,
                    ),
                    FrappeRaisedButton(
                      minWidth: 120,
                      onPressed: () {
                        if (!showLiked) {
                          filters.add([
                            widget.doctype,
                            '_liked_by',
                            'like',
                            '%$userId%',
                          ]);
                        } else {
                          int likedByIdx = FilterList.getFieldFilterIndex(
                            filters,
                            '_liked_by',
                          );

                          if (likedByIdx != null) {
                            filters.removeAt(likedByIdx);
                          }
                        }

                        setState(() {
                          showLiked = !showLiked;
                          _pageLoadController.reset();
                        });
                      },
                      title: 'Liked',
                      icon: showLiked
                          ? FrappeIcons.favourite_active
                          : FrappeIcons.favourite_resting,
                      iconSize: 16.0,
                    ),
                    Spacer()
                  ],
                ),
              ),
            ),
            body: HeaderAppBar(
              subtitle: widget.doctype,
              subActions: <Widget>[
                Padding(
                  padding: const EdgeInsets.all(10.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Palette.primaryButtonColor,
                    ),
                    child: IconButton(
                      icon: FrappeIcon(
                        FrappeIcons.small_add,
                        color: Colors.white,
                      ),
                      onPressed: () {
                        locator<NavigationService>().navigateTo(
                          Routes.newDoc,
                          arguments: NewDocArguments(
                            doctype: widget.doctype,
                          ),
                        );
                      },
                    ),
                  ),
                )
              ],
              body: RefreshIndicator(
                onRefresh: () async {
                  await _pageLoadController.reset();
                },
                child: Container(
                  color: Palette.bgColor,
                  child: isOnline
                      ? PagewiseListView(
                          padding: EdgeInsets.zero,
                          noItemsFoundBuilder: (context) {
                            return _noItemsFoundBuilder(filters);
                          },
                          pageLoadController: _pageLoadController,
                          itemBuilder: ((buildContext, entry, _) {
                            return _generateItem(
                              data: entry,
                              meta: meta.docs[0],
                              onListTap: () {
                                locator<NavigationService>().navigateTo(
                                  Routes.customRouter,
                                  arguments: CustomRouterArguments(
                                    viewType: ViewType.form,
                                    doctype: widget.doctype,
                                    name: entry["name"],
                                  ),
                                );
                              },
                              onButtonTap: (filter) async {
                                filters.clear();
                                filters.addAll(
                                  await FilterList.generateFilters(
                                      widget.doctype, filter),
                                );
                                _pageLoadController.reset();
                                setState(() {});
                              },
                            );
                          }),
                        )
                      : FutureBuilder(
                          future: CacheHelper.getCache('${widget.doctype}List'),
                          builder: (buildContext, snapshot) {
                            if (snapshot.hasData &&
                                snapshot.connectionState ==
                                    ConnectionState.done) {
                              var list = snapshot.data["data"];

                              if (list != null) {
                                list = list;
                                return ListView.builder(
                                  itemCount: list.length,
                                  itemBuilder: (context, index) {
                                    return _generateItem(
                                      data: list[index],
                                      onListTap: () {
                                        locator<NavigationService>().navigateTo(
                                          Routes.customRouter,
                                          arguments: CustomRouterArguments(
                                            viewType: ViewType.form,
                                            doctype: widget.doctype,
                                            name: list[index]["name"],
                                          ),
                                        );
                                      },
                                      onButtonTap: (filter) async {
                                        filters.clear();
                                        filters.addAll(
                                          await FilterList.generateFilters(
                                              widget.doctype, filter),
                                        );
                                        _pageLoadController.reset();
                                        setState(() {});
                                      },
                                    );
                                  },
                                );
                              } else {
                                return NoInternet(true);
                              }
                            } else if (snapshot.hasError) {
                              return Text(snapshot.error);
                            } else {
                              return Center(
                                child: CircularProgressIndicator(),
                              );
                            }
                          },
                        ),
                ),
              ),
            ),
          );
        } else {
          return Scaffold(
            body: snapshot.hasError
                ? Center(child: Text(snapshot.error))
                : Center(
                    child: CircularProgressIndicator(),
                  ),
          );
        }
      },
    );
  }
}