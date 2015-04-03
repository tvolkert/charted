/*
 * Copyright 2014 Google Inc. All rights reserved.
 *
 * Use of this source code is governed by a BSD-style
 * license that can be found in the LICENSE file or at
 * https://developers.google.com/open-source/licenses/bsd
 */

part of charted.charts;

class StackedBarChartRenderer extends BaseRenderer {
  final Iterable<int> dimensionsUsingBand = const[0];

  /*
   * Returns false if the number of dimension axes on the area is 0.
   * Otherwise, the first dimension scale is used to render the chart.
   */
  @override
  bool prepare(ChartArea area, ChartSeries series) {
    _ensureAreaAndSeries(area, series);
    return area is CartesianChartArea;
  }

  @override
  void draw(Element element,
      {bool preRender: false, Future schedulePostRender}) {
    _ensureReadyToDraw(element);
    var verticalBars = !area.config.leftAxisIsPrimary;

    var measuresCount = series.measures.length,
    measureScale = area.measureScales(series).first,
    dimensionScale = area.dimensionScales.first;

    var rows = new List()
      ..addAll(area.data.rows.map((e) {
      var row = [];
      for (var i = series.measures.length - 1; i >= 0; i--) {
        row.add(e[series.measures.elementAt(i)]);
      }
      return row;
    }));

    // We support only one dimension, so always use the first one.
    var x = area.data.rows.map(
            (row) => row.elementAt(area.config.dimensions.first)).toList();

    var group = root.selectAll('.row-group').data(rows);
    group.enter.append('g')
      ..classed('row-group')
      ..attrWithCallback('transform', (d, i, c) =>
          verticalBars ? 'translate(${dimensionScale.scale(x[i])}, 0)' :
          'translate(0, ${dimensionScale.scale(x[i])})');
    group.exit.remove();

    group.transition()
      ..attrWithCallback('transform', (d, i, c) =>
          verticalBars ? 'translate(${dimensionScale.scale(x[i])}, 0)' :
          'translate(0, ${dimensionScale.scale(x[i])})')
      ..duration(theme.transitionDuration)
      ..attrWithCallback('data-row', (d, i, e) => i);

    /* TODO(prsd): Handle cases where x and y axes are swapped */
    var bar = group.selectAll('.bar').dataWithCallback((d, i, c) => rows[i]);

    var ic = -1,
    order = 0,
    prevY = new List();

    prevY.add(0);
    bar.each((d, i, e) {
      if (i > ic) {
        prevY[prevY.length - 1] = e.attributes['y'];
      } else {
        prevY.add(e.attributes['y']);
      }
      ic = i;
    });

    ic = 1000000000;
    var enter = bar.enter.append('rect')
      ..classed('bar')
      ..styleWithCallback('fill', (d, i, c) => colorForKey(_reverseIdx(i)))
      ..attr(verticalBars ? 'width' : 'height', dimensionScale.rangeBand -
          theme.defaultStrokeWidth)
      ..attrWithCallback(verticalBars ? 'y' : 'x', (d, i, c) {
      var tempY;
      if (i <= ic && i > 0) {
        tempY = prevY[order];
        order++;
      } else {
        tempY = verticalBars ? rect.height : 0;
      }
      ic = i;
      return tempY;
    })
      ..attr(verticalBars ? 'height' : 'width', 0)
      ..on('click', (d, i, e) => _event(mouseClickController, d, i, e))
      ..on('mouseover', (d, i, e) => _event(mouseOverController, d, i, e))
      ..on('mouseout', (d, i, e) => _event(mouseOutController, d, i, e));

    bar.transition()
      ..styleWithCallback('fill', (d, i, c) => colorForKey(_reverseIdx(i)))
      ..attr(verticalBars ? 'width' : 'height', dimensionScale.rangeBand -
          theme.defaultStrokeWidth)
      ..duration(theme.transitionDuration);

    var y = 0,
    length = bar.length,
    // Keeps track of heights of previously graphed bars. If all bars before
    // current one have 0 height, the current bar doesn't need offset.
    prevAllZeroHeight = true,
    // Keeps track of the offset already exist in the previous bar, when the
    // computed bar height is less than (theme.defaultSeparatorWidth +
    // theme.defaultStrokeWidth), this height is already discounted, so the
    // next bar's offset in height can be this much less than normal.
    prevOffset = 0;

    bar.transition()
      ..attrWithCallback(verticalBars ? 'y' : 'x', (d, i, c) {
        if (verticalBars) {
          if (i == 0) y = measureScale.scale(0).round();
          return (y -= (rect.height - measureScale.scale(d).round()));
        } else {
          if (i == 0) {
            // 1 to not overlap the axis line.
            y = 1;
          }
          var pos = y;
          y += measureScale.scale(d).round();
          // Check if after adding the height of the bar, if y has changed, if
          // changed, we offset for space between the bars.
          if (y != pos) {
            y += (theme.defaultSeparatorWidth + theme.defaultStrokeWidth);
          }
          return pos;
        }
    })
      ..attrWithCallback(verticalBars ? 'height' : 'width', (d, i, c) {
        if (!verticalBars) return measureScale.scale(d).round();
        var ht = rect.height - measureScale.scale(d).round();
        if (i != 0) {
          // If previous bars has 0 height, don't offset for spacing
          // If any of the previous bar has non 0 height, do the offset.
          ht -= prevAllZeroHeight ? 1 :
          (theme.defaultSeparatorWidth + theme.defaultStrokeWidth);
          ht += prevOffset;
        } else {
          // When rendering next group of bars, reset prevZeroHeight.
          prevOffset = 0;
          prevAllZeroHeight = true;
          ht -= 1;
          // -1 so bar does not overlap x axis.
        }
        if (ht <= 0) {
          prevOffset = prevAllZeroHeight ? 0 :
          (theme.defaultSeparatorWidth + theme.defaultStrokeWidth) + ht;
          ht = 0;
        }
        prevAllZeroHeight = (ht == 0) && prevAllZeroHeight;
        return ht;
    })
      ..duration(theme.transitionDuration)
      ..delay(50);

    if (theme.defaultStrokeWidth > 0) {
      enter.attr('stroke-width', '${theme.defaultStrokeWidth}px');
      enter.styleWithCallback('stroke', (d, i, c) =>
          colorForKey(_reverseIdx(i)));
      bar.transition()
        ..styleWithCallback('stroke', (d, i, c) => colorForKey(_reverseIdx(i)));
    }

    bar.exit.remove();
  }

  @override
  double get bandInnerPadding =>
      area.theme.dimensionAxisTheme.axisBandInnerPadding;

  @override
  Extent get extent {
    assert(area != null && series != null);
    var rows = area.data.rows,
    max = rows[0][series.measures.first],
    min = max;

    rows.forEach((row) {
      if (row[series.measures.first] < min)
        min = row[series.measures.first];

      var bar = 0;
      series.measures.forEach((idx) {
        bar += row[idx];
      });
      if (bar > max) max = bar;
    });

    return new Extent(min, max);
  }

  void _event(StreamController controller, data, int index, Element e) {
    if (controller == null) return;
    var rowStr = e.parent.dataset['row'];
    var row = rowStr != null ? int.parse(rowStr) : null;
    controller.add(new _ChartEvent(
        scope.event, area, series, row, _reverseIdx(index), data));
  }

  // Because waterfall bar chart render the measures in reverse order to match
  // the legend, we need to reverse the index for color and event.
  int _reverseIdx(int index) => series.measures.length - 1 - index;
}
