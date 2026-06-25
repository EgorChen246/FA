import sys
import json
import os
import math
from PyQt5.QtWidgets import QApplication, QWidget
from PyQt5.QtGui import QPainter, QPen, QColor
from PyQt5.QtCore import QTimer, QPointF

class WaveSimulation(QWidget):
    def __init__(self):
        super().__init__() # для всплывающего окна
        self.setWindowTitle("Волны и поплавки")
        self.setGeometry(100, 100, 800, 600)
        
        self.base_y = 300
        self.width = 800
        self.height = 600
        self.g = 1.0
        self.rho = 1.0
        self.damping = 0.5
        self.v = 100.0
        self.t = 0.0
        self.dt = 0.01
        
        self.load_state()  # нач сост
        
        self.timer = QTimer(self)  # создаем таймер, и вызиваем для анимации расчет
        self.timer.timeout.connect(self.update_simulation)
        self.timer.start(10)  # 10 мс
    
    def load_state(self):  # созд. файла
        filename = 'initial_state.json'
        if os.path.exists(filename):  # проверка на сущ или сами присв
            with open(filename, 'r') as f:
                data = json.load(f)
            self.waves = data['waves']  # список волн
            self.floats = data['floats']  # поплавков с позиц, массой, об, радиус
        else:
            self.waves = [
                {'amplitude': 50, 'period': 2.0, 'phase': 0.0},
                {'amplitude': 30, 'period': 3.0, 'phase': 0.5},
                {'amplitude': 20, 'period': 4.0, 'phase': 1.0}
            ]  
            self.floats = [
                {'x': 200, 'y': 0, 'v': 0, 'mass': 10, 'volume': 15, 'radius': 20},
                {'x': 400, 'y': 0, 'v': 0, 'mass': 25, 'volume': 26, 'radius': 28},
                {'x': 600, 'y': 0, 'v': 0, 'mass': 12, 'volume': 18, 'radius': 22}
            ]
            with open(filename, 'w') as f:  # сохр файл
                json.dump({'waves': self.waves, 'floats': self.floats}, f)
    
    def wave_height(self, x, t):  # Выч высоту волны в т. х в t 
        h = 0.0
        for wave in self.waves:
            lambda1 = self.v * wave['period']  # длина волны
            k = 2 * math.pi / lambda1  # волновое число
            omega = 2 * math.pi / wave['period']  # угл частота

            h += wave['amplitude'] * math.sin(omega * t - k * x + wave['phase'])  # движ слева направа
        return self.base_y - h
    
    def update_simulation(self):  # Обн сост модели по таймеру
        self.t += self.dt
        for float in self.floats:
            h = self.wave_height(float['x'], self.t)  # для каждого попл h
            
            # Ускорения (с помощью Архимеда): a = (rho * volume / mass) * (h - y) - g - damping * v
            k = self.rho * float['volume'] / float['mass']
            a = k * (h - float['y']) - self.g - self.damping * float['v']
            
            float['v'] += a * self.dt  # обн скорость и позицию
            float['y'] += float['v'] * self.dt
        self.update()
    
    def paintEvent(self, event):  # Переопр метод для отрисовки гр
        painter = QPainter(self)
        painter.setRenderHint(QPainter.Antialiasing)  # сглаживание
        
        pen = QPen(QColor(0, 0, 255), 2)  # рис волну
        painter.setPen(pen)
        points = []
        for x in range(0, self.width + 1, 5):  # ген 5 пикселей
            y = self.wave_height(x, self.t)
            points.append(QPointF(x, y))
        painter.drawPolyline(points)
        
        for float in self.floats:  # попл
            painter.setBrush(QColor(255, 0, 0))
            painter.drawEllipse(int(float['x'] - float['radius']), int(float['y'] - float['radius']), int(2 * float['radius']), int(2 * float['radius']))


app = QApplication(sys.argv)
window = WaveSimulation()
window.show()
sys.exit(app.exec_())