# boid.py
import pygame
import math
from pygame.math import Vector2
import random

class Boid:
    def __init__(self, x, y, config):
        self.config = config
        self.pos = Vector2(x, y)
        angle = random.uniform(0, math.pi * 2)
        speed = random.uniform(config["min_speed"], config["max_speed"])
        self.vel = Vector2(math.cos(angle), math.sin(angle)) * speed
        self.acc = Vector2(0, 0)

    def update(self, boids):
        self.acc = Vector2(0, 0)

        separation_vec = Vector2(0, 0)
        alignment_vec = Vector2(0, 0)
        cohesion_vec = Vector2(0, 0)

        nearby = 0
        for other in boids:
            if other is self:
                continue
            d = self.pos.distance_to(other.pos)
            if d < self.config["perception"]:
                nearby += 1

                # Разделение
                if self.config["separation_enabled"] and d < 25:
                    diff = self.pos - other.pos
                    if d > 0:
                        diff = diff.normalize() / d
                    separation_vec += diff

                # Выравнивание и сплоченность
                if self.config["alignment_enabled"]:
                    alignment_vec += other.vel
                if self.config["cohesion_enabled"]:
                    cohesion_vec += other.pos

        if nearby > 0:
            w_sep = self.config["separation_weight"]
            w_ali = self.config["alignment_weight"]
            w_coh = self.config["cohesion_weight"]

            if self.config["separation_enabled"] and separation_vec.length() > 0:
                separation_vec = separation_vec.normalize() * self.config["max_speed"]
                self.acc += (separation_vec - self.vel) * w_sep

            if self.config["alignment_enabled"]:
                alignment_vec /= nearby
                if alignment_vec.length() > 0:
                    alignment_vec = alignment_vec.normalize() * self.config["max_speed"]
                    self.acc += (alignment_vec - self.vel) * w_ali

            if self.config["cohesion_enabled"]:
                cohesion_vec /= nearby
                to_center = cohesion_vec - self.pos
                if to_center.length() > 0:
                    to_center = to_center.normalize() * self.config["max_speed"]
                    self.acc += (to_center - self.vel) * w_coh

        # ограничение скорости
        if self.vel.length() > self.config["max_speed"]:
            self.vel = self.vel.normalize() * self.config["max_speed"]
        if self.vel.length() < self.config["min_speed"]:
            self.vel = self.vel.normalize() * self.config["min_speed"]

        self.vel += self.acc
        self.pos += self.vel

        # отражение от краёв (мягкий поворот)
        margin = self.config["margin"]
        turn = self.config["turn_factor"]
        if self.pos.x < margin:
            self.vel.x += turn
        if self.pos.x > self.config["window_width"] - margin:
            self.vel.x -= turn
        if self.pos.y < margin:
            self.vel.y += turn
        if self.pos.y > self.config["window_height"] - margin:
            self.vel.y -= turn

    def draw(self, screen):
        # простая стрелка-треугольник
        size = self.config["boid_size"]
        direction = self.vel.normalize() if self.vel.length() > 0 else Vector2(1, 0)
        perp = Vector2(-direction.y, direction.x)

        p1 = self.pos + direction * size
        p2 = self.pos - direction * size * 0.5 + perp * size * 0.5
        p3 = self.pos - direction * size * 0.5 - perp * size * 0.5

        color = self.config["boid_color"]
        pygame.draw.polygon(screen, color, [p1, p2, p3])
