/****************************************************************************************
**
** Copyright (C) 2013 Jolla Ltd.
** Contact: Bea Lam <bea.lam@jollamobile.com>
** All rights reserved.
** 
** This file is part of Sailfish Silica UI component package.
**
** You may use this file under the terms of BSD license as follows:
**
** Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are met:
**     * Redistributions of source code must retain the above copyright
**       notice, this list of conditions and the following disclaimer.
**     * Redistributions in binary form must reproduce the above copyright
**       notice, this list of conditions and the following disclaimer in the
**       documentation and/or other materials provided with the distribution.
**     * Neither the name of the Jolla Ltd nor the
**       names of its contributors may be used to endorse or promote products
**       derived from this software without specific prior written permission.
** 
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
** ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
** WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
** DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDERS OR CONTRIBUTORS BE LIABLE FOR
** ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
** (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
** LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
** ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
** SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
**
****************************************************************************************/

import QtQuick 2.0
import Sailfish.Silica 1.0
import "private/DatePicker.js" as DatePickerScript
import "private"


// Note DatePicker uses month range 1-12, while JS Date uses month range 0-11,
// so the month must be converted accordingly in all uses of JS Date values.

Item {
    id: datePicker

    readonly property int year: date.getFullYear()
    readonly property int month: date.getMonth()+1
    readonly property int day: date.getDate()

    property date date: new Date()
    property string dateText: Qt.formatDate(date)
    property alias viewMoving: view.viewMovingImmediate

    property Component modelComponent
    property Component delegate: Component {
        MouseArea {
            width: datePicker._dateBoxSize
            height: datePicker._dateBoxSize

            Label {
                anchors.centerIn: parent
                text: model.day
                font.bold: model.day === datePicker._today.getDate()
                            && model.month === datePicker._today.getMonth()+1
                            && model.year === datePicker._today.getFullYear()
                color: {
                    if (model.day === datePicker.day
                            && model.month === datePicker.month
                            && model.year === datePicker.year) {
                        return Theme.highlightColor
                    } else if (model.day === datePicker._today.getDate()
                               && model.month === datePicker._today.getMonth()+1
                               && model.year === datePicker._today.getFullYear()) {
                        return Theme.highlightColor
                    } else if (model.month === model.primaryMonth) {
                        return Theme.primaryColor
                    }
                    return Theme.secondaryColor
                }
            }

            onClicked: datePicker.date = new Date(model.year, model.month-1, model.day,12,0,0)
        }
    }

    default property alias pickerContent: viewChild.data

    property date _today: new Date()
    property bool _changingDate
    property bool _changeWithoutAnimation
    property int _dateBoxSize: width / 7
    property alias _gridView: view  // for testing

    signal updateModel(variant modelObject, variant fromDate, variant toDate, int primaryMonth)

    function showMonth(month, year) {
        if (month < 1 || month > 12) {
            console.log("DatePicker: showMonth() given invalid month:", month)
            return
        }
        if (month == datePicker.month && year == datePicker.year) {
            return
        }
        date = _validDate(year, month, day)
    }

    function _showMonth(month, year) {
        for (var i=0; i<monthModel.count; i++) {
            var y = monthModel.get(i).year
            var m = monthModel.get(i).month
            if (y === year && m === month) {
                if (i === view.currentIndex) {
                    return
                }
                var prevIndex = ((view.currentIndex - 1) + view.count) % view.count
                if (i === prevIndex) {
                    if (_changeWithoutAnimation) {
                        view.positionViewAtIndex(prevIndex, PathView.Center)
                        _changeWithoutAnimation = false
                    } else {
                        interactivityPrevention.restart()
                        view.decrementCurrentIndex()
                    }
                    return
                }
                var nextIndex = (view.currentIndex + 1) % view.count
                if (i === nextIndex) {
                    if (_changeWithoutAnimation) {
                        view.positionViewAtIndex(nextIndex, PathView.Center)
                        _changeWithoutAnimation = false
                    } else {
                        interactivityPrevention.restart()
                        view.incrementCurrentIndex()
                    }
                    return
                }
            }
        }
        // the month is not one of current/prev/next displayed months, just reload all the views
        monthModel.update(view.currentIndex, year, month)
    }

    function _validDate(year, month, day) {
        return new Date(year, month-1, Math.min(day, DatePickerScript._maxDaysForMonth(month, year)),12,0,0)
    }

    onDateChanged: {
        _changingDate = true
        var _year = date.getFullYear()
        var _month = date.getMonth() + 1
        _showMonth(_month, _year)
        _changingDate = false
    }

    width: Screen.width
    height: _dateBoxSize * 6

    Timer {
        id: interactivityPrevention
        interval: view.highlightMoveDuration
    }

    ListModel {
        id: monthModel

        function update(fromIndex, fromYear, fromMonth) {
            // show current month and the next
            var index = fromIndex
            var m = fromMonth
            var y = fromYear
            for (var i=0; i<count-1; i++) {
                _updateMonth(index, y, m)
                index = (index + 1) % count
                m += 1
                if (m > 12) {
                    y += 1
                    m = 1
                }
            }
            // previous item shows the previous month
            index = ((fromIndex - 1) + count) % count
            m = fromMonth - 1
            if (m >= 1) {
                _updateMonth(index, fromYear, m)
            } else {
                _updateMonth(index, fromYear-1, 12)
            }
        }

        function _updateMonth(index, y, m) {
            var data = get(index)
            if (data.year === y && data.month === m) {
                return
            }
            // needsUpdate helps avoid painting twice for two property changes
            setProperty(index, 'needsUpdate', false)
            set(index, {'year': y, 'month': m})
            setProperty(index, 'needsUpdate', true)
        }

        ListElement { year: -1; month: -1; needsUpdate: false }
        ListElement { year: -1; month: -1; needsUpdate: false }
        ListElement { year: -1; month: -1; needsUpdate: false }
    }

    SlideshowView {
        id: view

        property int weekColumnWidth: 140/480*Screen.width

        property bool viewMovingImmediate: view.moving || ((view.offset - Math.floor(view.offset)) != 0.)
        property bool noUpdateDelegate: false

        // prevent double tap from stopping just initiated month change
        interactive: !interactivityPrevention.running

        // Prevent PathView from generating all three calendar grids initially; just create the current grid
        pathItemCount: 1

        // We must slightly delay setting noUpdateDelegate back to false using a timer, as viewMovingImmediate
        // becomes false before the final view frame is painted.  So, if we don't delay, we get a jump on the
        // final frame
        onViewMovingImmediateChanged: {
            if (viewMovingImmediate == false)
                noUpdateDelegateTimer.restart()
            else
                noUpdateDelegate = true
        }

        Timer {
            id: noUpdateDelegateTimer
            interval: 32
            onTriggered: {
                if (false == view.viewMovingImmediate)
                    view.noUpdateDelegate = false
            }
        }

        width: parent.width
        height: parent.height
        itemWidth: view.width + weekColumnWidth
        itemHeight: view.height
        clip: true
        model: monthModel

        // set an appropriate highlight range for the initial display of a single grid delegate
        preferredHighlightBegin: 0.8875
        preferredHighlightEnd: 0.8875

        Timer {
            id: createNonVisibleGridsTimer
            interval: 100
            onTriggered: {
                // tell PathView to generate the rest of the grid delegates and adjust highlight accordingly
                view.pathItemCount = 3
                view.preferredHighlightBegin = 0.4625
                view.preferredHighlightEnd = 0.4625
            }
        }

        Component.onCompleted: {
            monthModel.update(view.currentIndex, datePicker.year, datePicker.month)
            createNonVisibleGridsTimer.start()
        }

        delegate: DateGrid {
            property bool modelNeedsUpdate: model.needsUpdate
            property bool viewMoving: view.noUpdateDelegate

            function testShouldUpdate() {
                // Update if an update is needed, and this grid is either in view or the SlideshowView has
                // stopped moving
                if (needsUpdate == false && (viewMoving == false || (x <= view.width && (x + width) > 0)))
                    needsUpdate = true
            }
            onModelNeedsUpdateChanged: {
                if (!modelNeedsUpdate)
                    needsUpdate = false
                else
                    testShouldUpdate()
            }
            onViewMovingChanged: testShouldUpdate()
            onXChanged: testShouldUpdate()

            gridWidth: view.width; height: view.height
            weekColumnWidth: view.weekColumnWidth
            displayedYear: model.year
            displayedMonth: model.month
            selectedDate: datePicker.date
            needsUpdate: model.needsUpdate
            modelComponent: datePicker.modelComponent
            delegate: datePicker.delegate

            onUpdateModel: datePicker.updateModel(modelObject, fromDate, toDate, primaryMonth)
        }

        onCurrentIndexChanged: {
            var data = monthModel.get(currentIndex)
            monthModel.update(currentIndex, data.year, data.month)
            if (!_changingDate) {
                datePicker.date = _validDate(data.year, data.month, datePicker.day)
            }
        }

        children: Item {
            id: viewChild
            anchors.fill: parent
            z: view.count + 1
        }
    }
}

